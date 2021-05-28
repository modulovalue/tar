import '../../base/interface/input_stream.dart';

/// A file contained in an Archive.
abstract class ArchiveFile {
  /// The uncompressed size of the file
  int get uncompressedSizeOfTheFile;

  String get name;

  int get mode;

  int get ownerId;

  int get groupId;

  int get lastModTime;

  bool get isFile;

  bool get isSymbolicLink;

  String get nameOfLinkedFile;

  /// The crc32 checksum of the uncompressed content.
  int? get crc32;

  String? get comment;

  /// If false, this file will not be compressed when encoded to an archive
  /// format such as zip.
  bool get compress;

  int get unixPermissions;

  /// Get the content of the file, decompressing on demand as necessary.
  dynamic get content;

  /// If the file data is compressed, decompress it.
  void decompress();

  /// Is the data stored by this file currently compressed?
  bool get isCompressed;

  /// What type of compression is the raw data stored in
  int? get compressionType;

  /// Get the content without decompressing it first.
  InputStream? get rawContent;
}
