import '../../base/impl/input_stream.dart';
import '../../base/interface/input_stream.dart';
import '../interface/file.dart';
import '../interface/header.dart';
import 'file.dart';

class ZipFileHeaderImpl implements ZipFileHeader {
  static const int SIGNATURE = 0x02014b50;
  @override
  int versionMadeBy = 0;
  @override
  int versionNeededToExtract = 0;
  @override
  int generalPurposeBitFlag = 0;
  @override
  int compressionMethod = 0;
  @override
  int lastModifiedFileTime = 0;
  @override
  int lastModifiedFileDate = 0;
  @override
  int? crc32;
  @override
  int? compressedSize;
  @override
  int? uncompressedSize;
  @override
  int? diskNumberStart;
  @override
  int? internalFileAttributes;
  @override
  int? externalFileAttributes;
  @override
  int? localHeaderOffset;
  @override
  String filename = '';
  @override
  List<int> extraField = [];
  @override
  String fileComment = '';
  @override
  ZipFile? file;

  ZipFileHeaderImpl([
    InputStream? input,
    InputStreamImpl? bytes,
    String? password,
  ]) {
    if (input != null) {
      versionMadeBy = input.readUint16();
      versionNeededToExtract = input.readUint16();
      generalPurposeBitFlag = input.readUint16();
      compressionMethod = input.readUint16();
      lastModifiedFileTime = input.readUint16();
      lastModifiedFileDate = input.readUint16();
      crc32 = input.readUint32();
      compressedSize = input.readUint32();
      uncompressedSize = input.readUint32();
      final fname_len = input.readUint16();
      final extra_len = input.readUint16();
      final comment_len = input.readUint16();
      diskNumberStart = input.readUint16();
      internalFileAttributes = input.readUint16();
      externalFileAttributes = input.readUint32();
      localHeaderOffset = input.readUint32();
      if (fname_len > 0) {
        filename = input.readString(size: fname_len);
      }
      if (extra_len > 0) {
        final extra = input.readBytes(extra_len);
        extraField = extra.toUint8List();
        final id = extra.readUint16();
        final size = extra.readUint16();
        if (id == 1) {
          // Zip64 extended information
          // Original
          // Size       8 bytes    Original uncompressed file size
          // Compressed
          // Size       8 bytes    Size of compressed data
          // Relative Header
          // Offset     8 bytes    Offset of local header record
          // Disk Start
          // Number     4 bytes    Number of the disk on which
          // this file starts
          if (size >= 8) {
            uncompressedSize = extra.readUint64();
          }
          if (size >= 16) {
            compressedSize = extra.readUint64();
          }
          if (size >= 24) {
            localHeaderOffset = extra.readUint64();
          }
          if (size >= 28) {
            diskNumberStart = extra.readUint32();
          }
        }
      }
      if (comment_len > 0) {
        fileComment = input.readString(size: comment_len);
      }
      if (bytes != null) {
        bytes.offset = localHeaderOffset!;
        file = ZipFileImpl(bytes, this, password);
      }
    }
  }

  @override
  String toString() => filename;
}
