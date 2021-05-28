import '../../archive/impl/constants.dart';
import '../../base/impl/exception.dart';
import '../../base/impl/input_stream.dart';
import '../../base/interface/input_stream.dart';
import '../../crc32/impl/crc32.dart';
import '../../zlib/impl/inflate.dart';
import '../interface/file.dart';
import '../interface/header.dart';

class ZipFileImpl implements ZipFile {
  static const int BZIP2 = 12;
  static const int SIGNATURE = 0x04034b50;

  /// Content of the file. If compressionMethod is not STORE, then it is
  /// still compressed.
  late InputStream _rawContent;
  List<int>? _content;
  int? _computedCrc32;
  bool _isEncrypted = false;
  final _keys = <int>[0, 0, 0];

  @override
  int signature = SIGNATURE;
  @override
  int version = 0;
  @override
  int flags = 0;
  @override
  int compressionMethod = 0;
  @override
  int lastModFileTime = 0;
  @override
  int lastModFileDate = 0;
  @override
  int? crc32;
  @override
  int? compressedSize;
  @override
  int? uncompressedSize;
  @override
  String filename = '';
  @override
  List<int> extraField = [];

  ZipFileImpl([InputStreamImpl? input, ZipFileHeader? header, String? password]) {
    if (input != null) {
      signature = input.readUint32();
      if (signature != SIGNATURE) {
        throw const ArchiveExceptionImpl('Invalid Zip Signature');
      } else {
        version = input.readUint16();
        flags = input.readUint16();
        compressionMethod = input.readUint16();
        lastModFileTime = input.readUint16();
        lastModFileDate = input.readUint16();
        crc32 = input.readUint32();
        compressedSize = input.readUint32();
        uncompressedSize = input.readUint32();
        final fn_len = input.readUint16();
        final ex_len = input.readUint16();
        filename = input.readString(size: fn_len);
        extraField = input.readBytes(ex_len).toUint8List();
        // Read compressedSize bytes for the compressed data.
        _rawContent = input.readBytes(header!.compressedSize!);
        if (password != null) {
          _initKeys(password);
          _isEncrypted = true;
        }
        // If bit 3 (0x08) of the flags field is set, then the CRC-32 and file
        // sizes are not known when the header is written. The fields in the
        // local header are filled with zero, and the CRC-32 and size are
        // appended in a 12-byte structure (optionally preceded by a 4-byte
        // signature) immediately after the compressed data:
        if (flags & 0x08 != 0) {
          final sigOrCrc = input.readUint32();
          if (sigOrCrc == 0x08074b50) {
            crc32 = input.readUint32();
          } else {
            crc32 = sigOrCrc;
          }
          compressedSize = input.readUint32();
          uncompressedSize = input.readUint32();
        }
      }
    }
  }

  @override
  bool verifyCrc32() {
    _computedCrc32 ??= const Crc32Impl().getCrc32(content);
    return _computedCrc32 == crc32;
  }

  @override
  List<int> get content {
    if (_content == null) {
      if (_isEncrypted) {
        _rawContent = _decodeRawContent(_rawContent);
        _isEncrypted = false;
      }
      if (compressionMethod == ARCHIVE_DEFLATE) {
        _content = InflateImpl.buffer(_rawContent, uncompressedSize).getBytes();
        compressionMethod = ARCHIVE_STORE;
      } else {
        _content = _rawContent.toUint8List();
      }
    }
    return _content!;
  }

  @override
  dynamic get rawContent {
    if (_content != null) {
      return _content;
    } else {
      return _rawContent;
    }
  }

  @override
  String toString() => filename;

  void _initKeys(String password) {
    _keys[0] = 305419896;
    _keys[1] = 591751049;
    _keys[2] = 878082192;
    password.codeUnits.forEach(_updateKeys);
  }

  void _updateKeys(int c) {
    _keys[0] = const Crc32Impl().CRC32(_keys[0], c);
    _keys[1] += _keys[0] & 0xff;
    _keys[1] = _keys[1] * 134775813 + 1;
    _keys[2] = const Crc32Impl().CRC32(_keys[2], _keys[1] >> 24);
  }

  int _decryptByte() {
    final temp = (_keys[2] & 0xffff) | 2;
    return ((temp * (temp ^ 1)) >> 8) & 0xff;
  }

  void _decodeByte(int c) => _updateKeys(c ^ _decryptByte());

  InputStreamImpl _decodeRawContent(InputStream input) {
    for (var i = 0; i < 12; ++i) {
      _decodeByte(_rawContent.readByte());
    }
    final bytes = _rawContent.toUint8List();
    for (var i = 0; i < bytes.length; ++i) {
      final temp = bytes[i] ^ _decryptByte();
      _updateKeys(temp);
      bytes[i] = temp;
    }
    return InputStreamImpl(bytes);
  }
}
