import 'dart:async';
import 'dart:typed_data';

import '../../base/constants.dart';
import '../../base/tar_exception.dart';
import '../../entry/impl/entry.dart';
import '../../entry/interface/entry.dart';
import '../../format/impl/formats.dart';
import '../../header/impl/header.dart';
import '../../header/impl/pay_headers.dart';
import '../../header/interface/header.dart';
import '../../header/interface/pax_headers.dart';
import '../../type_flag/impl/flags.dart';
import '../../util/is_all_zeroes.dart';
import '../../util/next_block_size.dart';
import '../../util/read_numeric.dart';
import '../../util/read_string.dart';
import '../../util/zeroes.dart';
import '../interface/tar_decoder.dart';

class TarDecoderImpl implements TarDecoder {
  /// A chunked stream iterator to enable us to get our data.
  final ChunkedStreamReader<int> _chunkedStream;
  final PaxHeaders _paxHeaders;
  final int _maxSpecialFileSize;

  /// Skip the next [_skipNext] elements when reading in the stream.
  int _skipNext = 0;

  TarEntry? _current;

  /// The underlying content stream for the [_current] entry. Draining this
  /// stream will move the tar reader to the beginning of the next file.
  ///
  /// This is not the same as `_current.stream` for sparse files, which are
  /// reported as expanded through [TarEntry.contents].
  /// For that reason, we prefer to drain this stream when skipping a tar entry.
  /// When we know we're skipping data, there's no point expanding sparse holes.
  ///
  /// This stream is always set to null after being drained, and there can only
  /// be one [_underlyingContentStream] at a time.
  Stream<List<int>>? _underlyingContentStream;

  /// Whether [_current] has ever been listened to.
  bool _listenedToContentsOnce = false;

  /// Whether we're in the process of reading tar headers.
  bool _isReadingHeaders = false;

  /// Whether this tar reader is terminally done.
  ///
  /// That is the case if:
  ///  - [cancel] was called
  ///  - [moveNext] completed to `false` once.
  ///  - [moveNext] completed to an error
  ///  - an error was emitted through a tar entry's content stream
  bool _isDone = false;

  /// Whether we should ensure that the stream emits no further data after the
  /// end of the tar file was reached.
  final bool _checkNoTrailingData;

  /// Creates a tar reader reading from the raw [tarStream].
  ///
  /// The [disallowTrailingData] parameter can be enabled to assert that the
  /// [tarStream] contains exactly one tar archive before ending.
  /// When [disallowTrailingData] is disabled (which is the default), the reader
  /// will automatically cancel its stream subscription when [moveNext] returns
  /// `false`.
  /// When it is enabled and a marker indicating the end of an archive is
  /// encountered, [moveNext] will wait for further events on the stream. If
  /// further data is received, a [TarException] will be thrown and the
  /// subscription will be cancelled. Otherwise, [moveNext] effectively waits
  /// for a done event, making a cancellation unecessary.
  /// Depending on the input stream, cancellations may cause unintended
  /// side-effects. In that case, [disallowTrailingData] can be used to ensure
  /// that the stream is only cancelled if it emits an invalid tar file.
  ///
  /// The [maxSpecialFileSize] parameter can be used to limit the maximum length
  /// of hidden entries in the tar stream. These entries include extended PAX
  /// headers or long names in GNU tar. The content of those entries has to be
  /// buffered in the parser to properly read the following tar entries. To
  /// avoid memory-based denial-of-service attacks, this library limits their
  /// maximum length. Changing the default of 2 KiB is rarely necessary.
  TarDecoderImpl(
    Stream<List<int>> tarStream, {
    int maxSpecialFileSize = defaultSpecialLength,
    bool disallowTrailingData = false,
  })  : _paxHeaders = PaxHeadersImpl.empty(),
        _chunkedStream = ChunkedStreamReader(tarStream),
        _checkNoTrailingData = disallowTrailingData,
        _maxSpecialFileSize = maxSpecialFileSize;

  @override
  TarEntry get current {
    final current = _current;
    if (current == null) {
      throw StateError('Invalid call to TarReader.current. \n'
          'Did you call and await next() and checked that it returned true?');
    } else {
      return current;
    }
  }

  /// Reads the tar stream up until the beginning of the next logical file.
  ///
  /// If such file exists, the returned future will complete with `true`. After
  /// the future completes, the next tar entry will be evailable in [current].
  ///
  /// If no such file exists, the future will complete with `false`.
  /// The future might complete with an [TarException] if the tar stream is
  /// malformed or ends unexpectedly.
  /// If the future completes with `false` or an exception, the reader will
  /// [cancel] itself and release associated resources. Thus, it is invalid to
  /// call [moveNext] again in that case.
  @override
  Future<bool> moveNext() async {
    await _prepareToReadHeaders();
    try {
      return await _moveNextInternal();
    } on Object {
      await cancel();
      rethrow;
    }
  }

  /// Consumes the stream up to the contents of the next logical tar entry.
  /// Will cancel the underlying subscription when returning false, but not when
  /// it throws.
  Future<bool> _moveNextInternal() async {
    // We're reading a new logical file, so clear the local pax headers
    _paxHeaders.clearLocals();
    var gnuLongName = '';
    var gnuLongLink = '';
    var eofAcceptable = true;
    var format = TarFormats.ustar | TarFormats.pax | TarFormats.gnu | TarFormats.v7 | TarFormats.star;
    TarHeaderImpl? nextHeader;
    // Externally, [moveNext] iterates through the tar archive as if it is a
    // series of files. Internally, the tar format often uses fake "files" to
    // add meta data that describes the next file. These meta data "files"
    // should not normally be visible to the outside. As such, this loop
    // iterates through one or more "header files" until it finds a
    // "normal file".
    for (;;) {
      if (_skipNext > 0) {
        await _readFullBlock(_skipNext);
        _skipNext = 0;
      }
      final rawHeader = await _readFullBlock(blockSize, allowEmpty: eofAcceptable);
      nextHeader = await _readHeader(rawHeader);
      if (nextHeader == null) {
        if (eofAcceptable) {
          await _handleExpectedEof();
          return false;
        } else {
          throw const TarExceptionHeaderUnexpectedEndOfFileImpl();
        }
      }
      // We're beginning to read a file, if the tar file ends now something is
      // wrong
      eofAcceptable = false;
      format = format.mayOnlyBe(nextHeader.format);
      // Check for PAX/GNU special headers and files.
      if (nextHeader.typeFlag == TypeFlags.xHeader || nextHeader.typeFlag == TypeFlags.xGlobalHeader) {
        format = format.mayOnlyBe(TarFormats.pax);
        final paxHeaderSize = _checkSpecialSize(nextHeader.size);
        final rawPaxHeaders = await _readFullBlock(paxHeaderSize);
        _paxHeaders.readPaxHeaders(rawPaxHeaders, nextHeader.typeFlag == TypeFlags.xGlobalHeader, true);
        _markPaddingToSkip(paxHeaderSize);
        // This is a meta header affecting the next header.
        continue;
      } else if (nextHeader.typeFlag == TypeFlags.gnuLongLink || nextHeader.typeFlag == TypeFlags.gnuLongName) {
        format = format.mayOnlyBe(TarFormats.gnu);
        final realName = await _readFullBlock(_checkSpecialSize(nextBlockSize(nextHeader.size)));
        final readName = readStringUint8List(realName, 0, realName.length);
        if (nextHeader.typeFlag == TypeFlags.gnuLongName) {
          gnuLongName = readName;
        } else {
          gnuLongLink = readName;
        }
        // This is a meta header affecting the next header.
        continue;
      } else {
        // The old GNU sparse format is handled here since it is technically
        // just a regular file with additional attributes.
        if (gnuLongName.isNotEmpty) nextHeader.name = gnuLongName;
        if (gnuLongLink.isNotEmpty) nextHeader.linkName = gnuLongLink;
        if (nextHeader.internalTypeFlag == TypeFlags.regA) {
          /// Legacy archives use trailing slash for directories
          if (nextHeader.name.endsWith('/')) {
            nextHeader.internalTypeFlag = TypeFlags.dir;
          } else {
            nextHeader.internalTypeFlag = TypeFlags.reg;
          }
        }
        final content = await _handleFile(nextHeader, rawHeader);
        // Set the final guess at the format
        if (format.has(TarFormats.ustar) && format.has(TarFormats.pax)) {
          format = format.mayOnlyBe(TarFormats.ustar);
        }
        nextHeader.format = format;
        _current = TarEntryImpl(nextHeader, content);
        _listenedToContentsOnce = false;
        _isReadingHeaders = false;
        return true;
      }
    }
  }

  @override
  Future<void> cancel() async {
    if (_isDone) {
      return;
    } else {
      _isDone = true;
      _current = null;
      _underlyingContentStream = null;
      _listenedToContentsOnce = false;
      _isReadingHeaders = false;
      // Note: Calling cancel is safe when the stream has already been completed.
      // It's a noop in that case, which is what we want.
      return _chunkedStream.cancel();
    }
  }

  /// Utility function for quickly iterating through all entries in [tarStream].
  static Future<void> forEach(Stream<List<int>> tarStream, FutureOr<void> Function(TarEntry entry) action) async {
    final reader = TarDecoderImpl(tarStream);
    try {
      while (await reader.moveNext()) {
        await action(reader.current);
      }
    } finally {
      await reader.cancel();
    }
  }

  /// Ensures that this reader can safely read headers now.
  ///
  /// This methods prevents:
  ///  * concurrent calls to [moveNext]
  ///  * a call to [moveNext] while a stream is active:
  ///    * if [contents] has never been listened to, we drain the stream
  ///    * otherwise, throws a [StateError]
  Future<void> _prepareToReadHeaders() async {
    if (_isDone) {
      throw StateError('Tried to call TarReader.moveNext() on a canceled '
          'reader. \n'
          'Note that a reader is canceled when moveNext() throws or returns '
          'false.');
    } else {
      if (_isReadingHeaders) {
        throw StateError('Concurrent call to TarReader.moveNext() detected. \n'
            'Please await all calls to Reader.moveNext().');
      } else {
        _isReadingHeaders = true;
        final underlyingStream = _underlyingContentStream;
        if (underlyingStream != null) {
          if (_listenedToContentsOnce) {
            throw StateError('Illegal call to TarReader.moveNext() while a previous stream was '
                'active.\n'
                'When listening to tar contents, make sure the stream is '
                'complete or cancelled before calling TarReader.moveNext() again.');
          } else {
            await underlyingStream.drain<void>();
            assert(_underlyingContentStream == null, "The stream should reset when drained (this should be done in _publishStream)");
          }
        }
      }
    }
  }

  int _checkSpecialSize(int size) {
    if (size > _maxSpecialFileSize) {
      throw TarExceptionHiddenEntryWithInvalidSizeImpl('TAR file contains hidden entry with an invalid size of $size.');
    } else {
      return size;
    }
  }

  /// Ater we detected the end of a tar file, optionally check for trailing data.
  Future<void> _handleExpectedEof() async {
    if (_checkNoTrailingData) {
      // Trailing zeroes are okay, but don't allow any more data here.
      Uint8List block;
      do {
        block = await ChunkedStreamReader.readBytes(_chunkedStream, blockSize);
        if (!isAllZeroes(block)) {
          throw const TarExceptionIllegalContentAfterEndOfArchiveImpl();
        }
      } while (block.length == blockSize);
      // The stream is done when we couldn't read the full block.
    }
    await cancel();
  }

  /// Reads a block with the requested [size], or throws an unexpected EoF
  /// exception.
  Future<Uint8List> _readFullBlock(int size, {bool allowEmpty = false}) async {
    final block = await ChunkedStreamReader.readBytes(_chunkedStream, size);
    if (block.length != size && !(allowEmpty && block.isEmpty)) {
      throw const TarExceptionHeaderUnexpectedEndOfFileImpl();
    }
    return block;
  }

  /// Reads the next block header and assumes that the underlying reader
  /// is already aligned to a block boundary. It returns the raw block of the
  /// header in case further processing is required.
  ///
  /// EOF is hit when one of the following occurs:
  ///	* Exactly 0 bytes are read and EOF is hit.
  ///	* Exactly 1 block of zeros is read and EOF is hit.
  ///	* At least 2 blocks of zeros are read.
  Future<TarHeaderImpl?> _readHeader(Uint8List rawHeader) async {
    // Exactly 0 bytes are read and EOF is hit.
    if (rawHeader.isEmpty) {
      return null;
    } else {
      if (isAllZeroes(rawHeader)) {
        final _rawHeader = await ChunkedStreamReader.readBytes(_chunkedStream, blockSize);
        // Exactly 1 block of zeroes is read and EOF is hit.
        if (_rawHeader.isEmpty) {
          return null;
        } else {
          if (isAllZeroes(_rawHeader)) {
            // Two blocks of zeros are read - Normal EOF.
            return null;
          } else {
            throw const TarExceptionNonZeroBlockAfterZeroBlockImpl();
          }
        }
      } else {
        return TarHeaderImpl.parseBlock(rawHeader, _paxHeaders);
      }
    }
  }

  /// Reports whether [sparseEntries] is a valid sparse map.
  /// It does not matter whether [sparseEntries] represents data fragments or
  /// hole fragments.
  static bool validateSparseEntries(List<SparseEntry> sparseEntries, int size) {
    // Validate all sparse entries. These are the same checks as performed by
    // the BSD tar utility.
    if (size < 0) {
      return false;
    } else {
      SparseEntry? previous;
      for (final current in sparseEntries) {
        if (current.offset < 0 || current.length < 0) {
          // Negative values are never okay.
          return false;
        } else if (current.offset + current.length < current.offset) {
          // Integer overflow with large length.
          return false;
        } else if (current.end > size) {
          // Region extends beyond the actual size.
          return false;
        } else if (previous != null && previous.end > current.offset) {
          // Regions cannot overlap and must be in order.
          return false;
        } else {
          previous = current;
        }
      }
      return true;
    }
  }

  /// Creates a stream of the next entry's content
  Future<Stream<List<int>>> _handleFile(TarHeaderImpl header, Uint8List rawHeader) async {
    List<SparseEntry>? sparseData;
    if (header.typeFlag == TypeFlags.gnuSparse) {
      sparseData = await _readOldGNUSparseMap(header, rawHeader);
    } else {
      sparseData = await _readGNUSparsePAXHeaders(header);
    }
    if (sparseData != null) {
      if (header.typeFlag.hasContent && !validateSparseEntries(sparseData, header.size)) {
        throw const TarExceptionHeaderInvalidSparseFileImpl();
      } else {
        final sparseHoles = invertSparseEntries(sparseData, header.size);
        final sparseDataLength = sparseData.fold<int>(0, (value, element) => value + element.length);
        final streamLength = nextBlockSize(sparseDataLength);
        final safeStream = _publishStream(_chunkedStream.readStream(streamLength), streamLength);
        return sparseStream(safeStream, sparseHoles, header.size);
      }
    } else {
      var size = header.size;
      if (!header.typeFlag.hasContent) size = 0;
      if (size < 0) {
        throw TarExceptionHeaderInvalidSizeImpl('Invalid size ($size) detected!');
      } else {
        if (size == 0) {
          return _publishStream(const Stream<Never>.empty(), 0);
        } else {
          _markPaddingToSkip(size);
          return _publishStream(_chunkedStream.readStream(header.size), header.size);
        }
      }
    }
  }

  /// Converts a sparse map ([source]) from one form to the other.
  /// If the input is sparse holes, then it will output sparse datas and
  /// vice-versa. The input must have been already validated.
  ///
  /// This function mutates [source] and returns a normalized map where:
  ///	* adjacent fragments are coalesced together
  ///	* only the last fragment may be empty
  ///	* the endOffset of the last fragment is the total size
  static List<SparseEntry> invertSparseEntries(List<SparseEntry> source, int size) {
    final result = <SparseEntry>[];
    var previous = const SparseEntryOffsetLengthImpl(0, 0);
    for (final current in source) {
      /// Skip empty fragments
      if (current.length != 0) {
        final newLength = current.offset - previous.offset;
        if (newLength > 0) {
          result.add(SparseEntryOffsetLengthImpl(previous.offset, newLength));
        }
        previous = SparseEntryOffsetLengthImpl(current.end, 0);
      }
    }
    final lastLength = size - previous.offset;
    result.add(SparseEntryOffsetLengthImpl(previous.offset, lastLength));
    return result;
  }

  /// Publishes an library-internal stream for users.
  ///
  /// This adds a check to ensure that the stream we're exposing has the
  /// expected length. It also sets the [_underlyingContentStream] field when
  /// the stream starts and resets it when it's done.
  Stream<List<int>> _publishStream(Stream<List<int>> stream, int length) {
    assert(
        _underlyingContentStream == null,
        "There can only be one content stream at a time. "
        "This precondition should be checked by _prepareToReadHeaders.");
    return _underlyingContentStream = Stream.eventTransformed(stream, (sink) {
      _listenedToContentsOnce = true;
      // ignore: close_sinks
      late _OutgoingStreamGuard guard;
      return guard = _OutgoingStreamGuard(
        length,
        sink,
        // Reset state when the stream is done. This will only be called when
        // the sream is done, not when a listener cancels.
        () {
          _underlyingContentStream = null;
          if (guard.hadError) {
            cancel();
          }
        },
      );
    });
  }

  /// Skips to the next block after reading [readSize] bytes from the beginning
  /// of a previous block.
  void _markPaddingToSkip(int readSize) {
    final offsetInLastBlock = readSize.toUnsigned(blockSizeLog2);
    if (offsetInLastBlock != 0) {
      _skipNext = blockSize - offsetInLastBlock;
    }
  }

  /// Checks the PAX headers for GNU sparse headers.
  /// If they are found, then this function reads the sparse map and returns it.
  /// This assumes that 0.0 headers have already been converted to 0.1 headers
  /// by the PAX header parsing logic.
  Future<List<SparseEntry>?> _readGNUSparsePAXHeaders(TarHeaderImpl header) async {
    /// Identify the version of GNU headers.
    var isVersion1 = false;
    final major = _paxHeaders.get(paxGNUSparseMajor);
    final minor = _paxHeaders.get(paxGNUSparseMinor);
    final sparseMapHeader = _paxHeaders.get(paxGNUSparseMap);
    if (major == '0' && (minor == '0' || minor == '1') ||
        // assume 0.0 or 0.1 if no version header is set
        sparseMapHeader != null && sparseMapHeader.isNotEmpty) {
      isVersion1 = false;
    } else if (major == '1' && minor == '0') {
      isVersion1 = true;
    } else {
      // Unknown version that we don't support
      return null;
    }
    header.format |= TarFormats.pax;

    /// Update [header] from GNU sparse PAX headers.
    final possibleName = _paxHeaders.get(paxGNUSparseName) ?? '';
    if (possibleName.isNotEmpty) {
      header.name = possibleName;
    }
    final possibleSize = _paxHeaders.get(paxGNUSparseSize) ?? _paxHeaders.get(paxGNUSparseRealSize);
    if (possibleSize != null && possibleSize.isNotEmpty) {
      final size = int.tryParse(possibleSize, radix: 10);
      if (size == null) {
        throw TarExceptionHeaderInvalidPaxSizeImpl('Invalid PAX size ($possibleSize) detected');
      }
      header.size = size;
    }
    // Read the sparse map according to the appropriate format.
    if (isVersion1) {
      return _readGNUSparseMap1x0();
    } else {
      return _readGNUSparseMap0x1(header);
    }
  }

  /// Reads the sparse map as stored in GNU's PAX sparse format version 1.0.
  /// The format of the sparse map consists of a series of newline-terminated
  /// numeric fields. The first field is the number of entries and is always
  /// present. Following this are the entries, consisting of two fields
  /// (offset, length). This function must stop reading at the end boundary of
  /// the block containing the last newline.
  ///
  /// Note that the GNU manual says that numeric values should be encoded in
  /// octal format. However, the GNU tar utility itself outputs these values in
  /// decimal. As such, this library treats values as being encoded in decimal.
  Future<List<SparseEntry>> _readGNUSparseMap1x0() async {
    var newLineCount = 0;
    final block = <int>[];

    /// Ensures that [block] h as at least [n] tokens.
    Future<void> feedTokens(int n) async {
      while (newLineCount < n) {
        final newBlock = await ChunkedStreamReader.readBytes(_chunkedStream, blockSize);
        if (newBlock.length < blockSize) {
          throw const TarExceptionHeaderSparseMapsNotEnoughLinesImpl();
        }
        block.addAll(newBlock);
        newLineCount += newBlock.where((byte) => byte == $lf).length;
      }
    }

    /// Get the next token delimited by a newline. This assumes that
    /// at least one newline exists in the buffer.
    String nextToken() {
      newLineCount--;
      final nextNewLineIndex = block.indexOf($lf);
      final result = block.sublist(0, nextNewLineIndex);
      block.removeRange(0, nextNewLineIndex + 1);
      return readStringUint8List(result, 0, nextNewLineIndex);
    }

    await feedTokens(1);
    // Parse for the number of entries.
    // Use integer overflow resistant math to check this.
    final numEntriesString = nextToken();
    final numEntries = int.tryParse(numEntriesString);
    if (numEntries == null || numEntries < 0 || 2 * numEntries < numEntries) {
      throw TarExceptionHeaderInvalidSparseMapNumberOfEntriesImpl('Invalid sparse map number of entries: $numEntriesString!');
    } else {
      // Parse for all member entries.
      // [numEntries] is trusted after this since a potential attacker must have
      // committed resources proportional to what this library used.
      await feedTokens(2 * numEntries);
      final sparseData = <SparseEntry>[];
      for (var i = 0; i < numEntries; i++) {
        final offsetToken = nextToken();
        final lengthToken = nextToken();
        final offset = int.tryParse(offsetToken);
        final length = int.tryParse(lengthToken);
        if (offset == null || length == null) {
          throw TarExceptionHeaderFailedToReadGnuMapEntryImpl('Failed to read a GNU sparse map entry #1. Encountered '
              'offset: $offsetToken, length: $lengthToken');
        }
        sparseData.add(SparseEntryOffsetLengthImpl(offset, length));
      }
      return sparseData;
    }
  }

  /// Reads the sparse map as stored in GNU's PAX sparse format version 0.1.
  /// The sparse map is stored in the PAX headers and is stored like this:
  /// `offset₀,size₀,offset₁,size₁...`
  List<SparseEntry> _readGNUSparseMap0x1(TarHeader header) {
    // Get number of entries, check for integer overflows
    final numEntriesString = _paxHeaders.get(paxGNUSparseNumBlocks);
    final numEntries = numEntriesString != null ? int.tryParse(numEntriesString) : null;
    if (numEntries == null || numEntries < 0 || 2 * numEntries < numEntries) {
      throw const TarExceptionHeaderInvalidGnuVersionMap1Impl();
    } else {
      // There should be two numbers in [sparseMap] for each entry.
      final sparseMap = _paxHeaders.get(paxGNUSparseMap)?.split(',');
      if (sparseMap == null) {
        throw const TarExceptionHeaderInvalidGnuVersionMap2Impl();
      } else {
        if (sparseMap.length != 2 * numEntries) {
          throw TarExceptionHeaderSparseMapLengthNotTwiceOfEntriesImpl('Detected sparse map length ${sparseMap.length} '
              'that is not twice the number of entries $numEntries');
        } else {
          /// Loop through sparse map entries.
          /// [numEntries] is now trusted.
          final sparseData = <SparseEntry>[];
          for (var i = 0; i < sparseMap.length; i += 2) {
            final offset = int.tryParse(sparseMap[i]);
            final length = int.tryParse(sparseMap[i + 1]);
            if (offset == null || length == null) {
              throw TarExceptionHeaderFailedToReadGnuMapEntryImpl('Failed to read a GNU sparse map entry #2. Encountered '
                  'offset: $offset, length: $length');
            }
            sparseData.add(SparseEntryOffsetLengthImpl(offset, length));
          }
          return sparseData;
        }
      }
    }
  }

  /// Reads the sparse map from the old GNU sparse format.
  /// The sparse map is stored in the tar header if it's small enough.
  /// If it's larger than four entries, then one or more extension headers are
  /// used to store the rest of the sparse map.
  ///
  /// [TarHeader.size] does not reflect the size of any extended headers used.
  /// Thus, this function will read from the chunked stream iterator to fetch
  /// extra headers.
  ///
  /// See also: https://www.gnu.org/software/tar/manual/html_section/tar_94.html#SEC191
  Future<List<SparseEntry>> _readOldGNUSparseMap(TarHeaderImpl header, Uint8List rawHeader) async {
    // Make sure that the input format is GNU.
    // Unfortunately, the STAR format also has a sparse header format that uses
    // the same type flag but has a completely different layout.
    if (header.format != TarFormats.gnu) {
      throw const TarExceptionHeaderSparseMapOfNonGnuHeaderImpl();
    } else {
      header.size = readNumeric(rawHeader, 483, 12);
      final sparseMaps = <Uint8List>[];
      var sparse = Uint8List.sublistView(rawHeader, 386, 483);
      sparseMaps.add(sparse);
      for (;;) {
        final maxEntries = sparse.length ~/ 24;
        if (sparse[24 * maxEntries] > 0) {
          // If there are more entries, read an extension
          // header and parse its entries.
          sparse = await ChunkedStreamReader.readBytes(_chunkedStream, blockSize);
          sparseMaps.add(sparse);
        } else {
          break;
        }
      }
      try {
        return _processOldGNUSparseMap(sparseMaps);
      } on FormatException {
        throw const TarExceptionInvalidOldGnuSparseMapImpl();
      }
    }
  }

  /// Process [sparseMaps], which is known to be an OLD GNU v0.1 sparse map.
  ///
  /// For details, see https://www.gnu.org/software/tar/manual/html_section/tar_94.html#SEC191
  List<SparseEntry> _processOldGNUSparseMap(List<Uint8List> sparseMaps) {
    final sparseData = <SparseEntry>[];
    for (final sparseMap in sparseMaps) {
      final maxEntries = sparseMap.length ~/ 24;
      for (var i = 0; i < maxEntries; i++) {
        // This termination condition is identical to GNU and BSD tar.
        if (sparseMap[i * 24] == 0) {
          // Don't return, need to process extended headers (even if empty)
          break;
        }
        final offset = readNumeric(sparseMap, i * 24, 12);
        final length = readNumeric(sparseMap, i * 24 + 12, 12);
        sparseData.add(SparseEntryOffsetLengthImpl(offset, length));
      }
    }
    return sparseData;
  }

  /// Generates a stream of the sparse file contents of size [size], given
  /// [sparseHoles] and the raw content in [source].
  static Stream<List<int>> sparseStream(Stream<List<int>> source, List<SparseEntry> sparseHoles, int size) {
    if (sparseHoles.isEmpty) {
      return ChunkedStreamReader(source).readStream(size);
    } else {
      return _sparseStream(source, sparseHoles, size);
    }
  }

  /// Generates a stream of the sparse file contents of size [size], given
  /// [sparseHoles] and the raw content in [source].
  ///
  /// [sparseHoles] has to be non-empty.
  static Stream<List<int>> _sparseStream(Stream<List<int>> source, List<SparseEntry> sparseHoles, int size) async* {
    // Current logical position in sparse file.
    var position = 0;
    // Index of the next sparse hole in [sparseHoles] to be processed.
    var sparseHoleIndex = 0;
    // Iterator through [source] to obtain the data bytes.
    final iterator = ChunkedStreamReader(source);
    while (position < size) {
      // Yield all the necessary sparse holes.
      while (sparseHoleIndex < sparseHoles.length && sparseHoles[sparseHoleIndex].offset == position) {
        final sparseHole = sparseHoles[sparseHoleIndex];
        yield* zeroes(sparseHole.length);
        position += sparseHole.length;
        sparseHoleIndex++;
      }
      if (position == size) {
        break;
      } else {
        /// Yield up to the next sparse hole's offset, or all the way to the end
        /// if there are no sparse holes left.
        var yieldTo = size;
        if (sparseHoleIndex < sparseHoles.length) {
          yieldTo = sparseHoles[sparseHoleIndex].offset;
        }
        // Yield data as substream, but make sure that we have enough data.
        var checkedPosition = position;
        await for (final chunk in iterator.readStream(yieldTo - position)) {
          yield chunk;
          checkedPosition += chunk.length;
        }
        if (checkedPosition != yieldTo) {
          throw const TarExceptionInvalidSparseDataUnexpectedEndOfInputStreamImpl();
        } else {
          position = yieldTo;
        }
      }
    }
  }
}

/// Event-sink tracking the length of emitted tar entry streams.
///
/// [ChunkedStreamReader.readStream] might return a stream shorter than
/// expected. That indicates an invalid tar file though, since the correct size
/// is stored in the header.
class _OutgoingStreamGuard extends EventSink<List<int>> {
  final int expectedSize;
  final EventSink<List<int>> out;
  void Function() onDone;

  int emittedSize = 0;
  bool hadError = false;

  _OutgoingStreamGuard(
    this.expectedSize,
    this.out,
    this.onDone,
  );

  @override
  void add(List<int> event) {
    emittedSize += event.length;
    // We have checks limiting the length of outgoing streams. If the stream is
    // larger than expected, that's a bug in pkg:tar.
    assert(
      emittedSize <= expectedSize,
      'Stream now emitted $emittedSize bytes, but only expected '
      '$expectedSize',
    );
    out.add(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    hadError = true;
    out.addError(error, stackTrace);
  }

  @override
  void close() {
    onDone();
    // If the stream stopped after an error, the user is already aware that
    // something is wrong.
    if (emittedSize < expectedSize && !hadError) {
      out.addError(const TarExceptionUnexpectedEndOfTarFileImpl(), StackTrace.current);
    }
    out.close();
  }
}

/// Represents a [length]-sized fragment at [offset] in a file.
///
/// [SparseEntry]s can represent either data or holes, and we can easily
/// convert between the two if we know the size of the file, all the sparse
/// data and all the sparse entries combined must give the full size.
abstract class SparseEntry {
  int get offset;

  int get length;

  int get end;
}

class SparseEntryOffsetLengthImpl implements SparseEntry {
  @override
  final int offset;
  @override
  final int length;

  const SparseEntryOffsetLengthImpl(this.offset, this.length);

  @override
  int get end => offset + length;

  @override
  String toString() => 'offset: $offset, length $length';

  @override
  bool operator ==(Object? other) => other is SparseEntry && offset == other.offset && length == other.length;

  @override
  int get hashCode => offset ^ length;
}

class ChunkedStreamReader<T> {
  final StreamIterator<List<T>> _input;
  final List<T> _emptyList = const [];
  List<T> _buffer = <T>[];
  bool _reading = false;

  ChunkedStreamReader(Stream<List<T>> stream) : _input = StreamIterator(stream);

  /// Read next [size] elements from _chunked stream_, buffering to create a
  /// chunk with [size] elements.
  ///
  /// This will read _chunks_ from the underlying _chunked stream_ until [size]
  /// elements have been buffered, or end-of-stream, then it returns the first
  /// [size] buffered elements.
  ///
  /// If end-of-stream is encountered before [size] elements is read, this
  /// returns a list with fewer than [size] elements (indicating end-of-stream).
  ///
  /// If the underlying stream throws, the stream is cancelled, the exception is
  /// propogated and further read operations will fail.
  ///
  /// Throws, if another read operation is on-going.
  Future<List<T>> readChunk(int size) async {
    final result = <T>[];
    // ignore: prefer_foreach
    await for (final chunk in readStream(size)) {
      result.addAll(chunk);
    }
    return result;
  }

  /// Read next [size] elements from _chunked stream_ as a sub-stream.
  ///
  /// This will pass-through _chunks_ from the underlying _chunked stream_ until
  /// [size] elements have been returned, or end-of-stream has been encountered.
  ///
  /// If end-of-stream is encountered before [size] elements is read, this
  /// returns a list with fewer than [size] elements (indicating end-of-stream).
  ///
  /// If the underlying stream throws, the stream is cancelled, the exception is
  /// propogated and further read operations will fail.
  ///
  /// If the sub-stream returned from [readStream] is cancelled the remaining
  /// unread elements up-to [size] are drained, allowing subsequent
  /// read-operations to proceed after cancellation.
  ///
  /// Throws, if another read-operation is on-going.
  Stream<List<T>> readStream(int size) {
    RangeError.checkNotNegative(size, 'size');
    if (_reading) {
      throw StateError('Concurrent read operations are not allowed!');
    } else {
      _reading = true;
      final substream = () async* {
        // While we have data to read
        while (size > 0) {
          // Read something into the buffer, if it's empty
          if (_buffer.isEmpty) {
            if (!(await _input.moveNext())) {
              // Don't attempt to read more data, as there is no more data.
              // ignore: parameter_assignments
              size = 0;
              _reading = false;
              break;
            }
            _buffer = _input.current;
          }
          if (_buffer.isNotEmpty) {
            if (size < _buffer.length) {
              final output = _buffer.sublist(0, size);
              _buffer = _buffer.sublist(size);
              // ignore: parameter_assignments
              size = 0;
              yield output;
              _reading = false;
              break;
            }
            final output = _buffer;
            // ignore: parameter_assignments
            size -= _buffer.length;
            _buffer = _emptyList;
            yield output;
          }
        }
      };
      final c = StreamController<List<T>>();
      c.onListen = () => c.addStream(substream()).whenComplete(c.close);
      c.onCancel = () async {
        while (size > 0) {
          if (_buffer.isEmpty) {
            if (!await _input.moveNext()) {
              // ignore: parameter_assignments
              size = 0; // no more data
              break;
            }
            _buffer = _input.current;
          }
          if (size < _buffer.length) {
            _buffer = _buffer.sublist(size);
            // ignore: parameter_assignments
            size = 0;
            break;
          }
          // ignore: parameter_assignments
          size -= _buffer.length;
          _buffer = _emptyList;
        }
        _reading = false;
      };
      return c.stream;
    }
  }

  /// Cancel the underlying _chunked stream_.
  ///
  /// If a future from [readChunk] or [readStream] is still pending then
  /// [cancel] behaves as if the underlying stream ended early. That is a future
  /// from [readChunk] may return a partial chunk smaller than the request size.
  ///
  /// It is always safe to call [cancel], even if the underlying stream was read
  /// to completion.
  ///
  /// It can be a good idea to call [cancel] in a `finally`-block when done
  /// using the [ChunkedStreamReader], this mitigates risk of leaking resources.
  Future<void> cancel() async => _input.cancel();

  /// This does the same as [readChunk], except it uses [_collectBytes] to create
  /// a [Uint8List], which offers better performance.
  static Future<Uint8List> readBytes(ChunkedStreamReader<int> reader, int size) =>
      _collectBytes(reader.readStream(size), (_, result) => result);

  /// Collects an asynchronous sequence of byte lists into a single list of bytes.
  ///
  /// If the [source] stream emits an error event,
  /// the collection fails and the returned future completes with the same error.
  ///
  /// If any of the input data are not valid bytes, they will be truncated to
  /// an eight-bit unsigned value in the resulting list.
  ///
  /// Performs all the same operations, but the final result is created
  /// by the [result] function, which has access to the stream subscription
  /// so it can cancel the operation.
  static T _collectBytes<T>(Stream<List<int>> source, T Function(StreamSubscription<List<int>>, Future<Uint8List>) result) {
    Uint8List joinListOfBytesWithKnownTotalLength(int length, List<List<int>> byteLists) {
      final result = Uint8List(length);
      var i = 0;
      for (final byteList in byteLists) {
        final end = i + byteList.length;
        result.setRange(i, end, byteList);
        i = end;
      }
      return result;
    }

    final byteLists = <List<int>>[];
    var length = 0;
    final completer = Completer<Uint8List>.sync();
    // ignore: cancel_subscriptions
    final subscription = source.listen(
      (bytes) {
        byteLists.add(bytes);
        length += bytes.length;
      },
      onError: completer.completeError,
      onDone: () => completer.complete(joinListOfBytesWithKnownTotalLength(length, byteLists)),
      cancelOnError: true,
    );
    return result(subscription, completer.future);
  }
}

class TarExceptionHeaderSparseMapLengthNotTwiceOfEntriesImpl extends FormatException implements TarException {
  const TarExceptionHeaderSparseMapLengthNotTwiceOfEntriesImpl(String message) : super('Invalid header: $message');
}

class TarExceptionHeaderInvalidSizeImpl extends FormatException implements TarException {
  const TarExceptionHeaderInvalidSizeImpl(String message) : super('Invalid header: $message');
}

class TarExceptionHeaderInvalidPaxSizeImpl extends FormatException implements TarException {
  const TarExceptionHeaderInvalidPaxSizeImpl(String message) : super('Invalid header: $message');
}

class TarExceptionHeaderFailedToReadGnuMapEntryImpl extends FormatException implements TarException {
  const TarExceptionHeaderFailedToReadGnuMapEntryImpl(String message) : super('Invalid header: $message');
}

class TarExceptionHeaderSparseMapsNotEnoughLinesImpl extends FormatException implements TarException {
  const TarExceptionHeaderSparseMapsNotEnoughLinesImpl() : super('Invalid header: GNU Sparse Map does not have enough lines!');
}

class TarExceptionHeaderInvalidSparseMapNumberOfEntriesImpl extends FormatException implements TarException {
  const TarExceptionHeaderInvalidSparseMapNumberOfEntriesImpl(String message) : super('Invalid header: $message');
}

class TarExceptionHeaderSparseMapOfNonGnuHeaderImpl extends FormatException implements TarException {
  const TarExceptionHeaderSparseMapOfNonGnuHeaderImpl() : super('Invalid header: Tried to read sparse map of non-GNU header');
}

class TarExceptionHeaderInvalidGnuVersionMap1Impl extends FormatException implements TarException {
  const TarExceptionHeaderInvalidGnuVersionMap1Impl() : super('Invalid header: Invalid GNU version 0.1 map 1');
}

class TarExceptionHeaderInvalidGnuVersionMap2Impl extends FormatException implements TarException {
  const TarExceptionHeaderInvalidGnuVersionMap2Impl() : super('Invalid header: Invalid GNU version 0.1 map 2');
}

class TarExceptionHeaderUnexpectedEndOfFileImpl extends FormatException implements TarException {
  const TarExceptionHeaderUnexpectedEndOfFileImpl() : super('Invalid header: unexpected end of file');
}

class TarExceptionHeaderInvalidSparseFileImpl extends FormatException implements TarException {
  const TarExceptionHeaderInvalidSparseFileImpl() : super('Invalid header: Invalid sparse file header.');
}

class TarExceptionHiddenEntryWithInvalidSizeImpl extends FormatException implements TarException {
  const TarExceptionHiddenEntryWithInvalidSizeImpl(String message) : super(message);
}

class TarExceptionIllegalContentAfterEndOfArchiveImpl extends FormatException implements TarException {
  const TarExceptionIllegalContentAfterEndOfArchiveImpl() : super('Illegal content after the end of the tar archive.');
}

class TarExceptionNonZeroBlockAfterZeroBlockImpl extends FormatException implements TarException {
  const TarExceptionNonZeroBlockAfterZeroBlockImpl() : super('Encountered a non-zero block after a zero block');
}

class TarExceptionInvalidOldGnuSparseMapImpl extends FormatException implements TarException {
  const TarExceptionInvalidOldGnuSparseMapImpl() : super('Invalid old GNU Sparse Map');
}

class TarExceptionInvalidSparseDataUnexpectedEndOfInputStreamImpl extends FormatException implements TarException {
  const TarExceptionInvalidSparseDataUnexpectedEndOfInputStreamImpl() : super('Invalid sparse data: Unexpected end of input stream');
}

class TarExceptionUnexpectedEndOfTarFileImpl extends FormatException implements TarException {
  const TarExceptionUnexpectedEndOfTarFileImpl() : super('Unexpected end of tar file');
}
