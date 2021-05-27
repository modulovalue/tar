import 'dart:typed_data';

import '../../base/constants.dart';
import '../../base/tar_exception.dart';
import '../../format/impl/formats.dart';
import '../../format/interface/format.dart';
import '../../header/interface/header.dart';
import '../../type_flag/impl/flags.dart';
import '../../type_flag/impl/parser.dart';
import '../../type_flag/interface/flag.dart';
import '../../util/compute_checksum.dart';
import '../../util/is_not_ascii.dart';
import '../../util/matches_header.dart';
import '../../util/parse_pax_time.dart';
import '../../util/read_numeric.dart';
import '../../util/read_octal.dart';
import '../../util/read_string.dart';
import '../../util/seconds_since_epoch.dart';
import '../interface/pax_headers.dart';

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
      name: readStringUint8List(headerBlock, 0, 100),
      mode: readOctal(headerBlock, 100, 8),
      // These should be octal, but some weird tar implementations ignore that?!
      // Encountered with package:RAL, version 1.28.0 on pub
      userId: readNumeric(headerBlock, 108, 8),
      groupId: readNumeric(headerBlock, 116, 8),
      size: size,
      modified: secondsSinceEpoch(readOctal(headerBlock, 136, 12)),
      typeFlag: () {
        final byte = headerBlock[156];
        final flag = tryParseTypeFlag(byte);
        if (flag == null) {
          throw TarExceptionInvalidTypeflagImpl._('Invalid typeflag value $byte');
        } else {
          return flag;
        }
      }(),
      linkName: readStringOrNullIfEmpty(headerBlock, 157, 100),
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
          prefix = readStringUint8List(headerBlock, 345, 155);
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
      final hasUstarMagic = matchesHeader(rawHeader, magicUstar, magicOffset);
      if (hasUstarMagic) {
        if (matchesHeader(rawHeader, trailerStar, starTrailerOffset)) {
          return TarFormats.star;
        } else {
          return TarFormats.ustar | TarFormats.pax;
        }
      } else if (matchesHeader(rawHeader, magicGnu, magicOffset) && matchesHeader(rawHeader, versionGnu, versionOffset)) {
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
