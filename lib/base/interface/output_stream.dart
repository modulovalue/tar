import 'input_stream.dart';

abstract class OutputStream {
  int get length;

  /// Write a byte to the output stream.
  void writeByte(int value);

  /// Write a set of bytes to the output stream.
  void writeBytes(List<int> bytes, [int? len]);

  /// Write an InputStream to the output stream.
  void writeInputStream(InputStream bytes);

  /// Write a 16-bit word to the output stream.
  void writeUint16(int value);

  /// Write a 32-bit word to the end of the buffer.
  void writeUint32(int value);
}
