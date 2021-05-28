import '../../base/interface/input_stream.dart';

abstract class Deflate {
  int get crc32;

  void finish();

  List<int> getBytes();

  /// Get the resulting compressed bytes without storing the resulting data to
  /// minimize memory usage.
  List<int> takeBytes();

  /// Add more data to be deflated.
  void addBytes(List<int> bytes, {int flush});

  /// Add more data to be deflated.
  void addBuffer(InputStream buffer, {int flush});

  /// Compression level used (1..9)
  int? get level;

  /// Set the data type to ASCII or BINARY, using a crude approximation:
  /// binary if more than 20% of the bytes are <= 6 or >= 128, ascii otherwise.
  /// IN assertion: the fields freq of dyn_ltree are set and the total of all
  /// frequencies does not exceed 64K (to fit in an int on 16 bit machines).
  void setDataType();

  /// Flush the bit buffer, keeping at most 7 bits in it.
  void biFlush();

  /// Read a buffer from the current input stream, update the adler32
  /// and total number of bytes read.  All deflate() input goes through
  /// this function so some applications may wish to modify it to avoid
  /// allocating a large strm->next_in buffer and copying from it.
  /// (See also flush_pending()).
  int get total;
}
