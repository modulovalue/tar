import 'dart:convert';

import '../../base/impl/constants.dart';
import '../../base/impl/input_stream.dart';
import '../../base/impl/output_stream.dart';
import '../../base/interface/archive.dart';
import '../../base/interface/file.dart';
import '../../base/interface/input_stream.dart';
import '../../base/interface/output_stream.dart';
import '../../crc32/impl/crc32.dart';
import '../../zlib/impl/deflate.dart';
import '../impl/directory.dart';
import '../impl/file.dart';
import '../impl/header.dart';
import '../interface/encoder.dart';

/// Encode an [Archive] object into a Zip formatted buffer.
class ZipEncoderImpl implements ZipEncoder {
  const ZipEncoderImpl();

  @override
  List<int>? encode(
    Archive archive, {
    int level = DeflateImpl.BEST_SPEED,
    OutputStream? output,
    DateTime? modified,
  }) {
    output ??= OutputStreamImpl();
    final session = startEncode(output, level: level, modified: modified);
    archive.iterable.forEach(session.addFile);
    session.endEncode(comment: archive.comment);
    if (output is OutputStreamImpl) {
      return output.getBytes();
    } else {
      return null;
    }
  }

  @override
  ZipEncodingSession startEncode(
    OutputStream? output, {
    int? level = DeflateImpl.BEST_SPEED,
    DateTime? modified,
  }) =>
      ZipEncodingSessionImpl(_ZipEncoderData(level, modified), output);
}

class ZipEncodingSessionImpl implements ZipEncodingSession {
  static const int VERSION = 20;

  // enum OS
  static const int OS_MSDOS = 0;
  static const int OS_UNIX = 3;
  static const int OS_MACINTOSH = 7;

  final _ZipEncoderData _data;
  final OutputStream? _output;

  const ZipEncodingSessionImpl(this._data, this._output);

  @override
  int getFileCrc32(ArchiveFile file) {
    if (file.content is InputStream) {
      final s = file.content as InputStream;
      s.reset();
      final bytes = s.toUint8List();
      final crc32 = const Crc32Impl().getCrc32(bytes);
      // ignore: avoid_dynamic_calls
      file.content.reset();
      return crc32;
    } else {
      return const Crc32Impl().getCrc32(file.content as List<int>);
    }
  }

  @override
  void addFile(ArchiveFile file) {
    final fileData = _ZipFileData();
    _data.files.add(fileData);
    fileData.name = file.name;
    fileData.time = _data.time;
    fileData.date = _data.date;
    fileData.mode = file.mode;
    fileData.isFile = file.isFile;
    InputStream? compressedData;
    int crc32;
    // If the user want's to store the file without compressing it,
    // make sure it's decompressed.
    if (!file.compress) {
      if (file.isCompressed) {
        file.decompress();
      }
      compressedData = (file.content is InputStream) ? file.content as InputStream : InputStreamImpl(file.content);
      if (file.crc32 != null) {
        crc32 = file.crc32!;
      } else {
        crc32 = getFileCrc32(file);
      }
    } else if (file.isCompressed && file.compressionType == ARCHIVE_DEFLATE) {
      // If the file is already compressed, no sense in uncompressing it and
      // compressing it again, just pass along the already compressed data.
      compressedData = file.rawContent;
      if (file.crc32 != null) {
        crc32 = file.crc32!;
      } else {
        crc32 = getFileCrc32(file);
      }
    } else {
      // Otherwise we need to compress it now.
      crc32 = getFileCrc32(file);
      dynamic bytes = file.content;
      if (bytes is InputStream) {
        bytes = bytes.toUint8List();
      }
      bytes = DeflateImpl(bytes as List<int>, level: _data.level).getBytes();
      compressedData = InputStreamImpl(bytes);
    }
    final filename = const Utf8Encoder().convert(file.name);
    final comment = file.comment != null ? const Utf8Encoder().convert(file.comment!) : null;
    _data.localFileSize += 30 + filename.length + compressedData!.length;
    _data.centralDirectorySize += 46 + filename.length + (comment != null ? comment.length : 0);
    fileData.crc32 = crc32;
    fileData.compressedSize = compressedData.length;
    fileData.compressedData = compressedData;
    fileData.uncompressedSize = file.uncompressedSizeOfTheFile;
    fileData.compress = file.compress;
    fileData.comment = file.comment;
    fileData.position = _output!.length;
    _writeFile(fileData, _output!);
    fileData.compressedData = null;
  }

  @override
  void endEncode({String? comment = ''}) {
    // Write Central Directory and End Of Central Directory
    _writeCentralDirectory(_data.files, comment, _output!);
  }

  void _writeFile(_ZipFileData fileData, OutputStream output) {
    final filename = fileData.name;
    output.writeUint32(ZipFileImpl.SIGNATURE);
    const version = VERSION;
    const flags = 0;
    final compressionMethod = fileData.compress ? ARCHIVE_DEFLATE : ARCHIVE_STORE;
    final lastModFileTime = fileData.time;
    final lastModFileDate = fileData.date;
    final crc32 = fileData.crc32;
    final compressedSize = fileData.compressedSize;
    final uncompressedSize = fileData.uncompressedSize;
    final extra = <int>[];
    final compressedData = fileData.compressedData!;
    final filenameUtf8 = const Utf8Encoder().convert(filename);
    output.writeUint16(version);
    output.writeUint16(flags);
    output.writeUint16(compressionMethod);
    output.writeUint16(lastModFileTime);
    output.writeUint16(lastModFileDate);
    output.writeUint32(crc32);
    output.writeUint32(compressedSize);
    output.writeUint32(uncompressedSize);
    output.writeUint16(filenameUtf8.length);
    output.writeUint16(extra.length);
    output.writeBytes(filenameUtf8);
    output.writeBytes(extra);
    output.writeInputStream(compressedData);
  }

  void _writeCentralDirectory(List<_ZipFileData> files, String? comment, OutputStream output) {
    // ignore: parameter_assignments
    comment ??= '';
    final commentUtf8 = const Utf8Encoder().convert(comment);
    final centralDirPosition = output.length;
    const version = VERSION;
    const os = OS_MSDOS;
    for (final fileData in files) {
      const versionMadeBy = (os << 8) | version;
      const versionNeededToExtract = version;
      const generalPurposeBitFlag = 0;
      final compressionMethod = fileData.compress ? ARCHIVE_DEFLATE : ARCHIVE_STORE;
      final lastModifiedFileTime = fileData.time;
      final lastModifiedFileDate = fileData.date;
      final crc32 = fileData.crc32;
      final compressedSize = fileData.compressedSize;
      final uncompressedSize = fileData.uncompressedSize;
      const diskNumberStart = 0;
      const internalFileAttributes = 0;
      final externalFileAttributes = fileData.mode << 16;
      /*if (!fileData.isFile) {
        externalFileAttributes |= 0x4000; // ?
      }*/
      final localHeaderOffset = fileData.position;
      final extraField = <int>[];
      final fileComment = fileData.comment ?? '';
      final filenameUtf8 = const Utf8Encoder().convert(fileData.name);
      final fileCommentUtf8 = const Utf8Encoder().convert(fileComment);
      output.writeUint32(ZipFileHeaderImpl.SIGNATURE);
      output.writeUint16(versionMadeBy);
      output.writeUint16(versionNeededToExtract);
      output.writeUint16(generalPurposeBitFlag);
      output.writeUint16(compressionMethod);
      output.writeUint16(lastModifiedFileTime);
      output.writeUint16(lastModifiedFileDate);
      output.writeUint32(crc32);
      output.writeUint32(compressedSize);
      output.writeUint32(uncompressedSize);
      output.writeUint16(filenameUtf8.length);
      output.writeUint16(extraField.length);
      output.writeUint16(fileCommentUtf8.length);
      output.writeUint16(diskNumberStart);
      output.writeUint16(internalFileAttributes);
      output.writeUint32(externalFileAttributes);
      output.writeUint32(localHeaderOffset);
      output.writeBytes(filenameUtf8);
      output.writeBytes(extraField);
      output.writeBytes(fileCommentUtf8);
    }
    const numberOfThisDisk = 0;
    const diskWithTheStartOfTheCentralDirectory = 0;
    final totalCentralDirectoryEntriesOnThisDisk = files.length;
    final totalCentralDirectoryEntries = files.length;
    final centralDirectorySize = output.length - centralDirPosition;
    final centralDirectoryOffset = centralDirPosition;
    output.writeUint32(ZipDirectoryImpl.SIGNATURE);
    output.writeUint16(numberOfThisDisk);
    output.writeUint16(diskWithTheStartOfTheCentralDirectory);
    output.writeUint16(totalCentralDirectoryEntriesOnThisDisk);
    output.writeUint16(totalCentralDirectoryEntries);
    output.writeUint32(centralDirectorySize);
    output.writeUint32(centralDirectoryOffset);
    output.writeUint16(commentUtf8.length);
    output.writeBytes(commentUtf8);
  }
}

class _ZipFileData {
  late String name;
  int time = 0;
  int date = 0;
  int crc32 = 0;
  int compressedSize = 0;
  int uncompressedSize = 0;
  InputStream? compressedData;
  bool compress = true;
  String? comment = '';
  int position = 0;
  int mode = 0;
  bool isFile = true;
}

class _ZipEncoderData {
  int? level;
  late final int time;
  late final int date;
  int localFileSize = 0;
  int centralDirectorySize = 0;
  int endOfCentralDirectorySize = 0;
  List<_ZipFileData> files = [];

  _ZipEncoderData(this.level, [DateTime? dateTime]) {
    dateTime = dateTime ?? DateTime.now();
    final t1 = ((dateTime.minute & 0x7) << 5) | (dateTime.second ~/ 2);
    final t2 = (dateTime.hour << 3) | (dateTime.minute >> 3);
    time = ((t2 & 0xff) << 8) | (t1 & 0xff);
    final d1 = ((dateTime.month & 0x7) << 5) | dateTime.day;
    final d2 = (((dateTime.year - 1980) & 0x7f) << 1) | (dateTime.month >> 3);
    date = ((d2 & 0xff) << 8) | (d1 & 0xff);
  }
}
