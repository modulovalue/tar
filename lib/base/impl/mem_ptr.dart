import 'dart:typed_data';

import '../interface/mem_ptr.dart';
import 'byte_order_constants.dart';
import 'exception.dart';

/// A helper class to work with List and TypedData in a way similar to pointers
/// in C.
class MemPtrImpl implements MemPtr {
  @override
  List<int> buffer;
  @override
  int offset;
  @override
  int byteOrder;
  int _length;

  MemPtrImpl(
    this.buffer, [
    this.offset = 0,
    this._length = -1,
    this.byteOrder = LITTLE_ENDIAN,
  ]) {
    if (_length < 0 || _length > buffer.length) {
      _length = buffer.length;
    }
  }

  MemPtrImpl.from(MemPtr other, [this.offset = 0, this._length = -1])
      : buffer = other.buffer,
        byteOrder = other.byteOrder {
    offset += other.offset;
    if (_length < 0) {
      _length = other.length;
    }
    if (_length > buffer.length) {
      _length = buffer.length;
    }
  }

  @override
  bool get isEOS => offset >= _length;

  @override
  int operator [](int index) => buffer[offset + index];

  @override
  void operator []=(int index, int value) => buffer[offset + index] = value;

  @override
  int get length => _length - offset;

  @override
  void memcpy(int start, int length, dynamic other, [int offset = 0]) {
    if (other is MemPtr) {
      buffer.setRange(this.offset + start, this.offset + start + length, other.buffer, other.offset + offset);
    } else {
      buffer.setRange(this.offset + start, this.offset + start + length, other as List<int>, offset);
    }
  }

  @override
  void memset(int start, int length, int value) {
    buffer.fillRange(offset + start, offset + start + length, value);
  }

  @override
  int readByte() => buffer[offset++];

  @override
  List<int> readBytes(int count) {
    if (buffer is Uint8List) {
      final b = buffer as Uint8List;
      final bytes = Uint8List.view(b.buffer, b.offsetInBytes + offset, count);
      offset += bytes.length;
      return bytes;
    } else {
      final bytes = buffer.sublist(offset, offset + count);
      offset += bytes.length;
      return bytes;
    }
  }

  @override
  String readString([int? len]) {
    if (len == null) {
      final codes = <int>[];
      while (!isEOS) {
        final c = readByte();
        if (c == 0) {
          return String.fromCharCodes(codes);
        }
        codes.add(c);
      }
      throw const ArchiveExceptionImpl('EOF reached without finding string terminator');
    } else {
      return String.fromCharCodes(readBytes(len));
    }
  }

  @override
  int readUint16() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    if (byteOrder == BIG_ENDIAN) {
      return (b1 << 8) | b2;
    } else {
      return (b2 << 8) | b1;
    }
  }

  @override
  int readUint24() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    final b3 = buffer[offset++] & 0xff;
    if (byteOrder == BIG_ENDIAN) {
      return b3 | (b2 << 8) | (b1 << 16);
    } else {
      return b1 | (b2 << 8) | (b3 << 16);
    }
  }

  @override
  int readUint32() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    final b3 = buffer[offset++] & 0xff;
    final b4 = buffer[offset++] & 0xff;
    if (byteOrder == BIG_ENDIAN) {
      return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
    } else {
      return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
    }
  }

  @override
  Uint8List? toUint8List([int offset = 0]) {
    if (buffer is TypedData) {
      final b = buffer as TypedData;
      return Uint8List.view(b.buffer, b.offsetInBytes + this.offset + offset);
    } else {
      return null;
    }
  }

  @override
  Uint32List? toUint32List([int offset = 0]) {
    if (buffer is TypedData) {
      final b = buffer as TypedData;
      return Uint32List.view(b.buffer, b.offsetInBytes + this.offset + offset);
    } else {
      return null;
    }
  }
}
