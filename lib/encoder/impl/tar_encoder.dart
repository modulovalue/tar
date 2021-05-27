import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../base/constants.dart';
import '../../entry/impl/entry.dart';
import '../../entry/interface/entry.dart';
import '../../format/impl/formats.dart';
import '../../header/impl/header.dart';
import '../../type_flag/impl/flags.dart';
import '../../type_flag/interface/flag.dart';
import '../../util/ms_since_epoch.dart';
import '../interface/tar_encoder.dart';

class TarEncoderSinkImpl extends StreamSink<TarEntry> implements TarEncoderSink {
  final StreamSink<List<int>> _output;
  @override
  final OutputFormat format;
  int _paxHeaderCount = 0;
  bool _closed = false;
  final Completer<Object?> _done = Completer();
  int _pendingOperations = 0;
  Future<void> _ready = Future.value();

  TarEncoderSinkImpl(this._output, this.format);

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> add(TarEntry event) {
    if (_closed) {
      throw StateError('Cannot add event after close was called');
    } else {
      return _doWork(() => _safeAdd(event));
    }
  }

  Future<void> _doWork(FutureOr<void> Function() work) {
    _pendingOperations++;
    // Chain futures to make sure we only write one entry at a time.
    return _ready = _ready.then((_) => work()).catchError(_output.addError).whenComplete(() {
      _pendingOperations--;
      if (_closed && _pendingOperations == 0) {
        _done.complete(_output.close());
      }
    });
  }

  Future<void> _safeAdd(TarEntry event) async {
    void setUint(Uint8List list, int value, int position, int length) {
      // Values are encoded as octal string, terminated and left-padded with
      // space chars.
      //
      // Set terminating space char.
      list[position + length - 1] = $space;
      // Write as octal value, we write from right to left
      var number = value;
      var needsExplicitZero = number == 0;
      for (var pos = position + length - 2; pos >= position; pos--) {
        if (number != 0) {
          // Write the last octal digit of the number (e.g. the last 4 bits)
          list[pos] = (number & 7) + $char0;
          // then drop the last digit (divide by 8 = 2³)
          number >>= 3;
        } else if (needsExplicitZero) {
          list[pos] = $char0;
          needsExplicitZero = false;
        } else {
          // done, left-pad with spaces
          list[pos] = $space;
        }
      }
    }

    final header = event.header;
    var size = header.size;
    Uint8List? bufferedData;
    if (size < 0) {
      final builder = BytesBuilder();
      await event.contents.forEach(builder.add);
      bufferedData = builder.takeBytes();
      size = bufferedData.length;
    }
    var nameBytes = utf8.encode(header.name);
    var linkBytes = utf8.encode(header.linkName ?? '');
    var gnameBytes = utf8.encode(header.groupName ?? '');
    var unameBytes = utf8.encode(header.userName ?? '');
    // We only get 100 chars for the name and link name. If they are longer, we
    // have to insert an entry just to store the names. Some tar implementations
    // expect them to be zero-terminated, so use 99 chars to be safe.
    final paxHeader = <String, List<int>>{};
    if (nameBytes.length > 99) {
      paxHeader[paxPath] = nameBytes;
      nameBytes = nameBytes.sublist(0, 99);
    }
    if (linkBytes.length > 99) {
      paxHeader[paxLinkpath] = linkBytes;
      linkBytes = linkBytes.sublist(0, 99);
    }
    // It's even worse for users and groups, where we only get 31 usable chars.
    if (gnameBytes.length > 31) {
      paxHeader[paxGname] = gnameBytes;
      gnameBytes = gnameBytes.sublist(0, 31);
    }
    if (unameBytes.length > 31) {
      paxHeader[paxUname] = unameBytes;
      unameBytes = unameBytes.sublist(0, 31);
    }
    if (size > maxIntFor12CharOct) {
      paxHeader[paxSize] = ascii.encode(size.toString());
    }
    if (paxHeader.isNotEmpty) {
      if (format == OutputFormat.pax) {
        await _writePaxHeader(paxHeader);
      } else {
        await _writeGnuLongName(paxHeader);
      }
    }
    final headerBlock = Uint8List(blockSize);
    headerBlock.setAll(0, nameBytes);
    setUint(headerBlock, header.mode, 100, 8);
    setUint(headerBlock, header.userId, 108, 8);
    setUint(headerBlock, header.groupId, 116, 8);
    setUint(headerBlock, size, 124, 12);
    setUint(headerBlock, header.modified.millisecondsSinceEpoch ~/ 1000, 136, 12);
    headerBlock[156] = header.typeFlag.flagByte;
    headerBlock.setAll(157, linkBytes);
    headerBlock.setAll(257, magicUstar);
    setUint(headerBlock, 0, 263, 2); // version
    headerBlock.setAll(265, unameBytes);
    headerBlock.setAll(297, gnameBytes);
    // To calculate the checksum, we first fill the checksum range with spaces
    headerBlock.setAll(148, List.filled(8, $space));
    // Then, we take the sum of the header
    var checksum = 0;
    for (final byte in headerBlock) {
      checksum += byte;
    }
    setUint(headerBlock, checksum, 148, 8);
    _output.add(headerBlock);
    // Write content.
    if (bufferedData != null) {
      _output.add(bufferedData);
    } else {
      await event.contents.forEach(_output.add);
    }
    final padding = -size % blockSize;
    _output.add(Uint8List(padding));
  }

  /// Writes an extended pax header.
  ///
  /// https://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html#tag_20_92_13_03
  Future<void> _writePaxHeader(Map<String, List<int>> values) {
    final buffer = BytesBuilder();
    // format of each entry: "%d %s=%s\n", <length>, <keyword>, <value>
    // note that the length includes the trailing \n and the length description
    // itself.
    values.forEach((key, value) {
      final encodedKey = utf8.encode(key);
      // +3 for the whitespace, the equals and the \n
      final payloadLength = encodedKey.length + value.length + 3;
      var indicatedLength = payloadLength;
      // The indicated length contains the length (in decimals) itself. So if
      // we had payloadLength=9, then we'd prefix a 9 at which point the whole
      // string would have a length of 10. If that happens, increment length.
      var actualLength = payloadLength + indicatedLength.toString().length;
      while (actualLength != indicatedLength) {
        indicatedLength++;
        actualLength = payloadLength + indicatedLength.toString().length;
      }
      // With that sorted out, let's add the line
      buffer
        ..add(utf8.encode(indicatedLength.toString()))
        ..addByte($space)
        ..add(encodedKey)
        ..addByte($equal)
        ..add(value)
        ..addByte($lf); // \n
    });
    final paxData = buffer.takeBytes();
    final file = TarEntryImpl(
      TarHeaderImpl(
        format: TarFormats.pax,
        modified: millisecondsSinceEpoch(0),
        name: 'PaxHeader/${_paxHeaderCount++}',
        mode: 0,
        size: paxData.length,
        typeFlag: TypeFlags.xHeader,
      ),
      Stream.value(paxData),
    );
    return _safeAdd(file);
  }

  Future<void> _writeGnuLongName(Map<String, List<int>> values) async {
    // Ensure that a file that can't be written in the GNU format is not written
    const allowedKeys = {paxPath, paxLinkpath};
    final invalidOptions = values.keys.toSet()..removeAll(allowedKeys);
    if (invalidOptions.isNotEmpty) {
      throw UnsupportedError(
        'Unsupported entry for OutputFormat.gnu. It uses long fields that '
        "can't be represented: $invalidOptions. \n"
        'Try using OutputFormat.pax instead.',
      );
    }
    final name = values[paxPath];
    final linkName = values[paxLinkpath];
    Future<void> write(List<int> name, TypeFlag flag) {
      return _safeAdd(
        TarEntryImpl(
          TarHeaderImpl(
            name: '././@LongLink',
            modified: millisecondsSinceEpoch(0),
            format: TarFormats.gnu,
            typeFlag: flag,
            size: name.length,
          ),
          Stream.value(name),
        ),
      );
    }

    if (name != null) {
      await write(name, TypeFlags.gnuLongName);
    }
    if (linkName != null) {
      await write(linkName, TypeFlags.gnuLongLink);
    }
  }

  @override
  void addError(
    Object error, [
    StackTrace? stackTrace,
  ]) =>
      _output.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<TarEntry> stream) async {
    await for (final entry in stream) {
      await add(entry);
    }
  }

  @override
  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      // Add two empty blocks at the end.
      await _doWork(() {
        _output.add(zeroBlock);
        _output.add(zeroBlock);
      });
    }
    return done;
  }
}

class TarEncoderTransformerImpl extends StreamTransformerBase<TarEntry, List<int>> implements TarEncoderTransformer {
  @override
  final OutputFormat format;

  const TarEncoderTransformerImpl(this.format);

  @override
  Stream<List<int>> bind(Stream<TarEntry> stream) {
    // sync because the controller proxies another stream
    // ignore: close_sinks
    final controller = StreamController<List<int>>(sync: true);
    controller.onListen = () => stream.pipe(TarEncoderSinkImpl(controller, format));
    return controller.stream;
  }
}
