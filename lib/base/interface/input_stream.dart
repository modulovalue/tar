import 'dart:typed_data';

import '../impl/input_stream.dart';

abstract class InputStream {
  ///  The current read position relative to the start of the buffer.
  int get position;

  /// How many bytes are left in the stream.
  int get length;

  /// Is the current position at the end of the stream?
  bool get isEOS;

  /// Reset to the beginning of the stream.
  void reset();

  /// Rewind the read head of the stream by the given number of bytes.
  void rewind([int length = 1]);

  /// Move the read position by [length] bytes.
  void skip(int length);

  /// Read [count] bytes from an [offset] of the current read position, without
  /// moving the read position.
  /// TODO this shouldn't return an implementation
  InputStreamImpl peekBytes(int count, [int offset = 0]);

  /// Read a single byte.
  int readByte();

  /// Read [count] bytes from the stream.
  /// TODO this shouldn't return an implementation
  InputStreamImpl readBytes(int count);

  /// Read a null-terminated string, or if [size] is provided, that number of
  /// bytes returned as a string.
  String readString({int? size, bool utf8 = true});

  /// Read a 16-bit word from the stream.
  int readUint16();

  /// Read a 24-bit word from the stream.
  int readUint24();

  /// Read a 32-bit word from the stream.
  int readUint32();

  /// Read a 64-bit word form the stream.
  int readUint64();

  Uint8List toUint8List();
}
