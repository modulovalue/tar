import '../../base/interface/output_stream.dart';

abstract class Bz2BitWriter {
  OutputStream get output;

  void writeByte(int byte);

  void writeBytes(List<int> bytes);

  void writeUint16(int value);

  void writeUint24(int value);

  void writeUint32(int value);

  void writeBits(int numBits, int value);

  /// Write any remaining bits from the buffer to the output, padding the
  /// remainder of the byte with 0's.
  void flush();
}
