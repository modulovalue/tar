import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../base/impl/byte_order_constants.dart';
import '../../base/impl/exception.dart';
import '../../base/impl/input_stream.dart';
import '../interface/input_file_stream.dart';

class InputFileStreamImpl implements InputFileStream {
  static const int _kDefaultBufferSize = 4096;

  @override
  final String path;
  final RandomAccessFile _file;
  @override
  final int byteOrder;
  int _fileSize = 0;
  final List<int> _buffer;
  int _filePosition = 0;
  int _bufferSize = 0;
  int _bufferPosition = 0;

  InputFileStreamImpl(
    this.path, {
    this.byteOrder = LITTLE_ENDIAN,
    int bufferSize = _kDefaultBufferSize,
  })  : _file = File(path).openSync(),
        _buffer = Uint8List(bufferSize) {
    _fileSize = _file.lengthSync();
    _readBuffer();
  }

  InputFileStreamImpl.file(
    File file, {
    this.byteOrder = LITTLE_ENDIAN,
    int bufferSize = _kDefaultBufferSize,
  })  : path = file.path,
        _file = file.openSync(),
        _buffer = Uint8List(bufferSize) {
    _fileSize = _file.lengthSync();
    _readBuffer();
  }

  @override
  void close() {
    _file.closeSync();
    _fileSize = 0;
  }

  @override
  int get length => _fileSize;

  @override
  int get position => _filePosition;

  @override
  bool get isEOS => (_filePosition >= _fileSize) && (_bufferPosition >= _bufferSize);

  @override
  int get bufferSize => _bufferSize;

  @override
  int get bufferPosition => _bufferPosition;

  @override
  int get bufferRemaining => _bufferSize - _bufferPosition;

  @override
  int get fileRemaining => _fileSize - _filePosition;

  @override
  void reset() {
    _filePosition = 0;
    _file.setPositionSync(0);
    _readBuffer();
  }

  @override
  void skip(int length) {
    if ((_bufferPosition + length) < _bufferSize) {
      _bufferPosition += length;
    } else {
      var remaining = length - (_bufferSize - _bufferPosition);
      while (!isEOS) {
        _readBuffer();
        if (remaining < _bufferSize) {
          _bufferPosition += remaining;
          break;
        }
        remaining -= _bufferSize;
      }
    }
  }

  /// Read [count] bytes from an [offset] of the current read position, without
  /// moving the read position.
  @override
  InputStreamImpl peekBytes(int count, [int offset = 0]) {
    final end = _bufferPosition + offset + count;
    if (end > 0 && end < _bufferSize) {
      final bytes = _buffer.sublist(_bufferPosition + offset, end);
      return InputStreamImpl(bytes);
    } else {
      final bytes = Uint8List(count);
      final remaining = _bufferSize - (_bufferPosition + offset);
      if (remaining > 0) {
        final bytes1 = _buffer.sublist(_bufferPosition + offset, _bufferSize);
        bytes.setRange(0, remaining, bytes1);
      }
      _file.readIntoSync(bytes, remaining, count);
      _file.setPositionSync(_filePosition);
      return InputStreamImpl(bytes);
    }
  }

  @override
  void rewind([int count = 1]) {
    if (_bufferPosition - count < 0) {
      final remaining = (_bufferPosition - count).abs();
      _filePosition = _filePosition - _bufferSize - remaining;
      if (_filePosition < 0) {
        _filePosition = 0;
      }
      _file.setPositionSync(_filePosition);
      _readBuffer();
    } else {
      _bufferPosition -= count;
    }
  }

  @override
  int readByte() {
    if (isEOS) {
      return 0;
    } else {
      if (_bufferPosition >= _bufferSize) {
        _readBuffer();
      }
      if (_bufferPosition >= _bufferSize) {
        return 0;
      } else {
        return _buffer[_bufferPosition++] & 0xff;
      }
    }
  }

  /// Read a 16-bit word from the stream.
  @override
  int readUint16() {
    var b1 = 0;
    var b2 = 0;
    if ((_bufferPosition + 2) < _bufferSize) {
      b1 = _buffer[_bufferPosition++] & 0xff;
      b2 = _buffer[_bufferPosition++] & 0xff;
    } else {
      b1 = readByte();
      b2 = readByte();
    }
    if (byteOrder == BIG_ENDIAN) {
      return (b1 << 8) | b2;
    } else {
      return (b2 << 8) | b1;
    }
  }

  /// Read a 24-bit word from the stream.
  @override
  int readUint24() {
    var b1 = 0;
    var b2 = 0;
    var b3 = 0;
    if ((_bufferPosition + 3) < _bufferSize) {
      b1 = _buffer[_bufferPosition++] & 0xff;
      b2 = _buffer[_bufferPosition++] & 0xff;
      b3 = _buffer[_bufferPosition++] & 0xff;
    } else {
      b1 = readByte();
      b2 = readByte();
      b3 = readByte();
    }
    if (byteOrder == BIG_ENDIAN) {
      return b3 | (b2 << 8) | (b1 << 16);
    } else {
      return b1 | (b2 << 8) | (b3 << 16);
    }
  }

  /// Read a 32-bit word from the stream.
  @override
  int readUint32() {
    var b1 = 0;
    var b2 = 0;
    var b3 = 0;
    var b4 = 0;
    if ((_bufferPosition + 4) < _bufferSize) {
      b1 = _buffer[_bufferPosition++] & 0xff;
      b2 = _buffer[_bufferPosition++] & 0xff;
      b3 = _buffer[_bufferPosition++] & 0xff;
      b4 = _buffer[_bufferPosition++] & 0xff;
    } else {
      b1 = readByte();
      b2 = readByte();
      b3 = readByte();
      b4 = readByte();
    }
    if (byteOrder == BIG_ENDIAN) {
      return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
    } else {
      return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
    }
  }

  /// Read a 64-bit word form the stream.
  @override
  int readUint64() {
    var b1 = 0;
    var b2 = 0;
    var b3 = 0;
    var b4 = 0;
    var b5 = 0;
    var b6 = 0;
    var b7 = 0;
    var b8 = 0;
    if ((_bufferPosition + 8) < _bufferSize) {
      b1 = _buffer[_bufferPosition++] & 0xff;
      b2 = _buffer[_bufferPosition++] & 0xff;
      b3 = _buffer[_bufferPosition++] & 0xff;
      b4 = _buffer[_bufferPosition++] & 0xff;
      b5 = _buffer[_bufferPosition++] & 0xff;
      b6 = _buffer[_bufferPosition++] & 0xff;
      b7 = _buffer[_bufferPosition++] & 0xff;
      b8 = _buffer[_bufferPosition++] & 0xff;
    } else {
      b1 = readByte();
      b2 = readByte();
      b3 = readByte();
      b4 = readByte();
      b5 = readByte();
      b6 = readByte();
      b7 = readByte();
      b8 = readByte();
    }
    if (byteOrder == BIG_ENDIAN) {
      return (b1 << 56) | (b2 << 48) | (b3 << 40) | (b4 << 32) | (b5 << 24) | (b6 << 16) | (b7 << 8) | b8;
    } else {
      return (b8 << 56) | (b7 << 48) | (b6 << 40) | (b5 << 32) | (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
    }
  }

  @override
  InputStreamImpl readBytes(int length) {
    if (isEOS) {
      return InputStreamImpl(<int>[]);
    } else {
      if (_bufferPosition == _bufferSize) {
        _readBuffer();
      }
      if (_remainingBufferSize >= length) {
        final bytes = _buffer.sublist(_bufferPosition, _bufferPosition + length);
        _bufferPosition += length;
        return InputStreamImpl(bytes);
      } else {
        final total_remaining = fileRemaining + _remainingBufferSize;
        if (length > total_remaining) {
          // ignore: parameter_assignments
          length = total_remaining;
        }
        final bytes = Uint8List(length);
        var offset = 0;
        while (length > 0) {
          final remaining = _bufferSize - _bufferPosition;
          final end = (length > remaining) ? _bufferSize : (_bufferPosition + length);
          final l = _buffer.sublist(_bufferPosition, end);
          // TODO probably better to use bytes.setRange here.
          for (var i = 0; i < l.length; ++i) {
            bytes[offset + i] = l[i];
          }
          offset += l.length;
          // ignore: parameter_assignments
          length -= l.length;
          _bufferPosition = end;
          // ignore: invariant_booleans, false positive?
          if (length > 0 && _bufferPosition == _bufferSize) {
            _readBuffer();
            if (_bufferSize == 0) {
              break;
            }
          }
        }
        return InputStreamImpl(bytes);
      }
    }
  }

  @override
  Uint8List toUint8List() => readBytes(_fileSize).toUint8List();

  /// Read a null-terminated string, or if [size] is provided, that number of
  /// bytes returned as a string.
  @override
  String readString({int? size, bool utf8 = true}) {
    if (size == null) {
      final codes = <int>[];
      while (!isEOS) {
        final c = readByte();
        if (c == 0) {
          return utf8 ? const Utf8Decoder().convert(codes) : String.fromCharCodes(codes);
        } else {
          codes.add(c);
        }
      }
      throw const ArchiveExceptionImpl('EOF reached without finding string terminator');
    } else {
      final s = readBytes(size);
      final bytes = s.toUint8List();
      final str = utf8 ? const Utf8Decoder().convert(bytes) : String.fromCharCodes(bytes);
      return str;
    }
  }

  int get _remainingBufferSize => _bufferSize - _bufferPosition;

  void _readBuffer() {
    _bufferPosition = 0;
    _bufferSize = _file.readIntoSync(_buffer);
    if (_bufferSize != 0) {
      _filePosition += _bufferSize;
    }
  }
}
