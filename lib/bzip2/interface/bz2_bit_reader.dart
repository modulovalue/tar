import '../../base/interface/input_stream.dart';

abstract class Bz2BitReader {
  InputStream get input;

  int readByte();

  /// Read a number of bits from the input stream.
  int readBits(int numBits);
}
