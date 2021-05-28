abstract class Crc32 {
  /// Get the CRC-32 checksum of the given int.
  int CRC32(int crc, int b);

  /// Get the CRC-32 checksum of the given array. You can append bytes to an
  /// already computed crc by specifying the previous [crc] value.
  int getCrc32(List<int> array, int crc);
}
