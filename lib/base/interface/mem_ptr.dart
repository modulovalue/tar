import 'dart:typed_data';

/// A helper class to work with List and TypedData
/// in a way similar to pointers in C.
abstract class MemPtr {
  List<int> get buffer;

  int get offset;

  int get byteOrder;

  /// Are we at the end of the buffer?
  bool get isEOS;

  /// Get a byte in the buffer relative to the current read position.
  int operator [](int index);

  /// Set a byte in the buffer relative to the current read position.
  void operator []=(int index, int value);

  /// The number of bytes remaining in the buffer.
  int get length;

  /// Copy data from [other] to this buffer, at [start] offset from the
  /// current read position, and [length] number of bytes.  [offset] is
  /// the offset in [other] to start reading.
  void memcpy(int start, int length, dynamic other, [int offset = 0]);

  /// Set a range of bytes in this buffer to [value],
  /// at [start] offset from the current read position,
  /// and [length] number of bytes.
  void memset(int start, int length, int value);

  /// Read a single byte.
  int readByte();

  /// Read [count] bytes from the buffer.
  List<int> readBytes(int count);

  /// Read a null-terminated string, or if [len] is provided,
  /// that number of bytes returned as a string.
  String readString([int? len]);

  /// Read a 16-bit word from the stream.
  int readUint16();

  /// Read a 24-bit word from the stream.
  int readUint24();

  /// Read a 32-bit word from the stream.
  int readUint32();

  /// This assumes buffer is a typed buffer.
  Uint8List? toUint8List([int offset = 0]);

  /// This assumes buffer is a typed buffer.
  Uint32List? toUint32List([int offset = 0]);
}
