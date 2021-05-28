abstract class ZipFile {
  // 4 bytes
  int get signature;

  // 2 bytes
  int get version;

  // 2 bytes
  int get flags;

  // 2 bytes
  int get compressionMethod;

  // 2 bytes
  int get lastModFileTime;

  // 2 bytes
  int get lastModFileDate;

  // 4 bytes
  int? get crc32;

  // 4 bytes
  int? get compressedSize;

  // 4 bytes
  int? get uncompressedSize;

  // 2 bytes length, n-bytes data
  String get filename;

  // 2 bytes length, n-bytes data
  List<int> get extraField;

  /// This will decompress the data (if necessary) in order to calculate the
  /// crc32 checksum for the decompressed data and verify it with the value
  /// stored in the zip.
  bool verifyCrc32();

  /// Get the decompressed content from the file.  The file isn't decompressed
  /// until it is requested.
  List<int> get content;

  dynamic get rawContent;
}
