import 'dart:convert';
import 'dart:typed_data';

import '../interface/flag.dart';
import '../interface/flags.dart';
import '../interface/format.dart';
import '../interface/header.dart';
import '../interface/tar_exception.dart';
import '../util/compute_checksum.dart';
import '../util/is_not_ascii.dart';
import '../util/matches_header.dart';
import '../util/parse_pax_time.dart';
import '../util/read_numeric.dart';
import '../util/read_octal.dart';
import '../util/read_string.dart';
import '../util/seconds_since_epoch.dart';
import 'constants.dart';
import 'format.dart';

class TarHeaderImpl implements TarHeader {
  TypeFlag internalTypeFlag;

  @override
  String name;

  @override
  String? linkName;

  @override
  int mode;

  @override
  int userId;

  @override
  int groupId;

  @override
  String? userName;

  @override
  String? groupName;

  @override
  int size;

  @override
  DateTime modified;

  @override
  DateTime? accessed;

  @override
  DateTime? changed;

  @override
  int devMajor;

  @override
  int devMinor;

  @override
  TarFormat format;

  @override
  TypeFlag get typeFlag => internalTypeFlag == TypeFlags.regA ? TypeFlags.reg : internalTypeFlag;

  /// Creates a tar header from the individual field.
  factory TarHeaderImpl({
    required String name,
    TarFormat? format,
    TypeFlag? typeFlag,
    DateTime? modified,
    String? linkName,
    int mode = 0,
    int size = -1,
    String? userName,
    int userId = 0,
    int groupId = 0,
    String? groupName,
    DateTime? accessed,
    DateTime? changed,
    int devMajor = 0,
    int devMinor = 0,
  }) =>
      TarHeaderImpl.internal(
        name: name,
        modified: modified ?? DateTime.fromMillisecondsSinceEpoch(0),
        format: format ?? TarFormats.pax,
        typeFlag: typeFlag ?? TypeFlags.reg,
        linkName: linkName,
        mode: mode,
        size: size,
        userName: userName,
        userId: userId,
        groupId: groupId,
        groupName: groupName,
        accessed: accessed,
        changed: changed,
        devMajor: devMajor,
        devMinor: devMinor,
      );

  /// This constructor is meant to help us deal with header-only headers (i.e.
  /// meta-headers that only describe the next file instead of being a header
  /// to files themselves)
  TarHeaderImpl.internal({
    required this.name,
    required this.modified,
    required this.format,
    required TypeFlag typeFlag,
    this.linkName,
    this.mode = 0,
    this.size = -1,
    this.userName,
    this.userId = 0,
    this.groupId = 0,
    this.groupName,
    this.accessed,
    this.changed,
    this.devMajor = 0,
    this.devMinor = 0,
  }) : internalTypeFlag = typeFlag;

  factory TarHeaderImpl.parseBlock(
    Uint8List headerBlock,
    PaxHeaders paxHeaders,
  ) {
    assert(headerBlock.length == 512, "Unexpected headerBlock length (${headerBlock.length}) expected 512.");
    final format = _getFormat(headerBlock);
    final size = paxHeaders.size ?? readOctal(headerBlock, 124, 12);
    // Start by reading data available in every format.
    final header = TarHeaderImpl(
      format: format,
      name: readStringUint8List(headerBlock, 0, nameSize),
      mode: readOctal(headerBlock, 100, 8),
      // These should be octal, but some weird tar implementations ignore that?!
      // Encountered with package:RAL, version 1.28.0 on pub
      userId: readNumeric(headerBlock, 108, 8),
      groupId: readNumeric(headerBlock, 116, 8),
      size: size,
      modified: secondsSinceEpoch(readOctal(headerBlock, 136, 12)),
      typeFlag: () {
        final byte = headerBlock[156];
        final flag = TypeFlags.tryParse(byte);
        if (flag == null) {
          throw TarExceptionInvalidTypeflagImpl._('Invalid typeflag value $byte');
        } else {
          return flag;
        }
      }(),
      linkName: readStringOrNullIfEmpty(headerBlock, 157, nameSize),
    );
    if (header.typeFlag.hasContent && size < 0) {
      throw TarExceptionInvalidSizeIndicatedImpl('Invalid header: indicates an invalid size of $size');
    } else {
      if (format.isValid() && format != TarFormats.v7) {
        // If it's a valid header that is not of the v7 format, it will have the
        // USTAR fields
        header
          ..userName ??= readStringOrNullIfEmpty(headerBlock, 265, 32)
          ..groupName ??= readStringOrNullIfEmpty(headerBlock, 297, 32)
          ..devMajor = readNumeric(headerBlock, 329, 8)
          ..devMinor = readNumeric(headerBlock, 337, 8);
        // Prefix to the file name
        var prefix = '';
        if (format.has(TarFormats.ustar) || format.has(TarFormats.pax)) {
          prefix = readStringUint8List(headerBlock, 345, prefixSize);
          if (headerBlock.any(isNotAscii)) {
            header.format = format.mayOnlyBe(TarFormats.pax);
          }
        } else if (format.has(TarFormats.star)) {
          prefix = readStringUint8List(headerBlock, 345, 131);
          header
            ..accessed = secondsSinceEpoch(readNumeric(headerBlock, 476, 12))
            ..changed = secondsSinceEpoch(readNumeric(headerBlock, 488, 12));
        } else if (format.has(TarFormats.gnu)) {
          header.format = TarFormats.gnu;
          if (headerBlock[345] != 0) {
            header.accessed = secondsSinceEpoch(readNumeric(headerBlock, 345, 12));
          }
          if (headerBlock[357] != 0) {
            header.changed = secondsSinceEpoch(readNumeric(headerBlock, 357, 12));
          }
        }
        if (prefix.isNotEmpty) {
          header.name = '$prefix/${header.name}';
        }
      }
      paxHeaders.forEach(header.processEntry);
      return header;
    }
  }

  /// Checks that [rawHeader] represents a valid tar header based on the
  /// checksum, and then attempts to guess the specific format based
  /// on magic values. If the checksum fails, then an error is thrown.
  static TarFormat _getFormat(Uint8List rawHeader) {
    final checksum = readOctal(rawHeader, checksumOffset, checksumLength);
    // Modern TAR archives use the unsigned checksum, but we check the signed
    // checksum as well for compatibility.
    if (checksum != computeUnsignedHeaderChecksum(rawHeader) && checksum != computeSignedHeaderChecksum(rawHeader)) {
      throw const TarExceptionChecksumDoesNotMatchImpl('Invalid header: checksum does not match');
    } else {
      final hasUstarMagic = matchesHeader(rawHeader, MagicValues.magicUstar, magicOffset);
      if (hasUstarMagic) {
        if (matchesHeader(rawHeader, MagicValues.trailerStar, starTrailerOffset)) {
          return TarFormats.star;
        } else {
          return TarFormats.ustar | TarFormats.pax;
        }
      } else if (matchesHeader(rawHeader, MagicValues.magicGnu, magicOffset) &&
          matchesHeader(rawHeader, MagicValues.versionGnu, versionOffset)) {
        return TarFormats.gnu;
      } else {
        return TarFormats.v7;
      }
    }
  }

  void processEntry(String key, String value) {
    if (value == '') {
      // Keep the original USTAR value.
    } else {
      switch (key) {
        case paxPath:
          name = value;
          break;
        case paxLinkpath:
          linkName = value;
          break;
        case paxUname:
          userName = value;
          break;
        case paxGname:
          groupName = value;
          break;
        case paxUid:
          try {
            userId = int.parse(value, radix: 10);
          } on FormatException catch (e) {
            throw TarExceptionInvalidPaxUidImpl("Invalid integer ${value} $e");
          }
          break;
        case paxGid:
          try {
            groupId = int.parse(value, radix: 10);
          } on FormatException catch (e) {
            throw TarExceptionInvalidPaxGidImpl("Invalid integer ${value} $e");
          }
          break;
        case paxAtime:
          accessed = parsePaxTime(value);
          break;
        case paxMtime:
          modified = parsePaxTime(value);
          break;
        case paxCtime:
          changed = parsePaxTime(value);
          break;
        case paxSize:
          try {
            size = int.parse(value, radix: 10);
          } on FormatException catch (e) {
            throw TarExceptionInvalidPaxSizeImpl("Invalid integer ${value} $e");
          }
          break;
      }
    }
  }
}

class TarExceptionInvalidPaxSizeImpl extends FormatException implements TarException {
  const TarExceptionInvalidPaxSizeImpl(String message) : super(message);
}

class TarExceptionInvalidPaxGidImpl extends FormatException implements TarException {
  const TarExceptionInvalidPaxGidImpl(String message) : super(message);
}

class TarExceptionInvalidPaxUidImpl extends FormatException implements TarException {
  const TarExceptionInvalidPaxUidImpl(String message) : super(message);
}

class TarExceptionInvalidTypeflagImpl extends FormatException implements TarException {
  const TarExceptionInvalidTypeflagImpl._(String message) : super(message);
}

class TarExceptionInvalidSizeIndicatedImpl extends FormatException implements TarException {
  const TarExceptionInvalidSizeIndicatedImpl(String message) : super(message);
}

class TarExceptionChecksumDoesNotMatchImpl extends FormatException implements TarException {
  const TarExceptionChecksumDoesNotMatchImpl(String message) : super(message);
}

class PaxHeadersImpl implements PaxHeaders {
  final Map<String, String> _globalHeaders;
  final Map<String, String> _localHeaders;

  PaxHeadersImpl(this._globalHeaders, this._localHeaders); // Not const because headers are mutable.

  factory PaxHeadersImpl.empty() => PaxHeadersImpl({}, {});

  @override
  void forEach(void Function(String key, String value) fn) {
    _globalHeaders.forEach(fn);
    _localHeaders.forEach(fn);
  }

  /// Applies new global PAX-headers from the map.
  ///
  /// The [headers] will replace global headers with the same key, but leave
  /// others intact.
  @override
  void newGlobals(Map<String, String> headers) => _globalHeaders.addAll(headers);

  @override
  void addLocal(String key, String value) => _localHeaders[key] = value;

  @override
  void removeLocal(String key) => _localHeaders.remove(key);

  /// Applies new local PAX-headers from the map.
  ///
  /// This replaces all currently active local headers.
  @override
  void newLocals(Map<String, String> headers) => _localHeaders
    ..clear()
    ..addAll(headers);

  /// Clears local headers.
  ///
  /// This is used by the reader after a file has ended, as local headers only
  /// apply to the next entry.
  @override
  void clearLocals() => _localHeaders.clear();

  @override
  String? get(Object? key) => _localHeaders[key] ?? _globalHeaders[key];

  @override
  Iterable<String> get keys => {..._globalHeaders.keys, ..._localHeaders.keys};

  /// Decodes the content of an extended pax header entry.
  ///
  /// Semantically, a [PAX Header][posix pax] is a map with string keys and
  /// values, where both keys and values are encodes with utf8.
  ///
  /// However, [old GNU Versions][gnu sparse00] used to repeat keys to store
  /// sparse file information in sparse headers. This method will transparently
  /// rewrite the PAX format of version 0.0 to version 0.1.
  ///
  /// [posix pax]: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html#tag_20_92_13_03
  /// [gnu sparse00]: https://www.gnu.org/software/tar/manual/html_section/tar_94.html#SEC192
  @override
  void readPaxHeaders(List<int> data, bool isGlobal, bool ignoreUnknown) {
    var offset = 0;
    final map = <String, String>{};
    final sparseMap = <String>[];
    while (offset < data.length) {
      // At the start of an entry, expect its length which is terminated by a
      // space char.
      final space = data.indexOf($space, offset);
      if (space == -1) {
        break;
      } else {
        var length = 0;
        var currentChar = data[offset];
        var charsInLength = 0;
        while (currentChar >= $char0 && currentChar <= $char9) {
          length = length * 10 + currentChar - $char0;
          charsInLength++;
          currentChar = data[++offset];
        }
        if (length == 0) {
          throw const TarExceptionInvalidPAXRecordImpl('Invalid header: invalid PAX record');
        } else {
          // Skip the whitespace
          if (currentChar != $space) {
            throw const TarExceptionInvalidPAXRecordImpl('Invalid header: invalid PAX record');
          } else {
            offset++;
            // Length also includes the length description and a space we just read
            final endOfEntry = offset + length - 1 - charsInLength;
            // checking against endOfEntry - 1 because the trailing whitespace is
            // optional for the last entry
            if (endOfEntry < offset || endOfEntry - 1 > data.length) {
              throw const TarExceptionInvalidPAXRecordImpl('Invalid header: invalid PAX record');
            } else {
              // Read the key
              final nextEquals = data.indexOf($equal, offset);
              if (nextEquals == -1 || nextEquals >= endOfEntry) {
                throw const TarExceptionInvalidPAXRecordImpl('Invalid header: invalid PAX record');
              } else {
                final key = const Utf8Decoder().convert(data, offset, nextEquals);
                // Skip over the equals sign
                offset = nextEquals + 1;
                // Subtract one for trailing newline
                final endOfValue = endOfEntry - 1;
                final value = const Utf8Decoder().convert(data, offset, endOfValue);
                if (!_isValidPaxRecord(key, value)) {
                  throw const TarExceptionInvalidPAXRecordImpl('Invalid header: invalid PAX record');
                } else {
                  // If we're seeing weird PAX Version 0.0 sparse keys, expect alternating
                  // GNU.sparse.offset and GNU.sparse.numbytes headers.
                  if (key == paxGNUSparseNumBytes || key == paxGNUSparseOffset) {
                    if ((sparseMap.length.isEven && key != paxGNUSparseOffset) ||
                        (sparseMap.length.isOdd && key != paxGNUSparseNumBytes) ||
                        value.contains(',')) {
                      throw const TarExceptionInvalidPAXRecordImpl('Invalid header: invalid PAX record');
                    } else {
                      sparseMap.add(value);
                    }
                  } else if (!ignoreUnknown || supportedPaxHeaders.contains(key)) {
                    // Ignore unrecognized headers to avoid unbounded growth of the global
                    // header map.
                    map[key] = value;
                  }
                  // Skip over value
                  offset = endOfValue;
                  // and the trailing newline
                  final hasNewline = offset < data.length;
                  if (hasNewline && data[offset] != $lf) {
                    throw const TarExceptionInvalidPAXRecordImpl('Invalid PAX Record (missing trailing newline)');
                  } else {
                    offset++;
                  }
                }
              }
            }
          }
        }
      }
      if (sparseMap.isNotEmpty) {
        map[paxGNUSparseMap] = sparseMap.join(',');
      }
      if (isGlobal) {
        newGlobals(map);
      } else {
        newLocals(map);
      }
    }
  }

  /// Checks whether [key], [value] is a valid entry in a pax header.
  ///
  /// This is adopted from the Golang tar reader (`validPAXRecord`), which says
  /// that "Keys and values should be UTF-8, but the number of bad writers out
  /// there forces us to be a more liberal."
  static bool _isValidPaxRecord(String key, String value) {
    // These limitations are documented in the PAX standard.
    if (key.isEmpty || key.contains('=')) {
      return false;
    } else {
      // These aren't, but Golangs's tar has them and got away with it.
      switch (key) {
        case paxPath:
        case paxLinkpath:
        case paxUname:
        case paxGname:
          return !value.codeUnits.contains(0);
        default:
          return !key.codeUnits.contains(0);
      }
    }
  }

  @override
  int? get size {
    final sizeStr = this.get(paxSize);
    if (sizeStr == null) {
      // ignore: avoid_returning_null
      return null;
    } else {
      return int.tryParse(sizeStr);
    }
  }
}

class TarExceptionInvalidPAXRecordImpl extends FormatException implements TarException {
  const TarExceptionInvalidPAXRecordImpl(String message) : super(message);
}
