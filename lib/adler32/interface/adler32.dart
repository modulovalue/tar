abstract class Adler32 {
  /// Get the Adler-32 checksum for the given array. You can append bytes to an
  /// already computed adler checksum by specifying the previous [adler] value.
  int getAdler32(List<int> array, int adler);
}
