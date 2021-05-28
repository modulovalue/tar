import 'file.dart';

abstract class ZipFileHeader {
  // 2 bytes
  int get versionMadeBy;

  // 2 bytes
  int get versionNeededToExtract;

  // 2 bytes
  int get generalPurposeBitFlag;

  // 2 bytes
  int get compressionMethod;

  // 2 bytes
  int get lastModifiedFileTime;

  // 2 bytes
  int get lastModifiedFileDate;

  // 4 bytes
  int? get crc32;

  // 4 bytes
  int? get compressedSize;

  // 4 bytes
  int? get uncompressedSize;

  // 2 bytes
  int? get diskNumberStart;

  // 2 bytes
  int? get internalFileAttributes;

  // 4 bytes
  int? get externalFileAttributes;

  // 4 bytes
  int? get localHeaderOffset;

  String get filename;

  List<int> get extraField;

  String get fileComment;

  ZipFile? get file;
}
