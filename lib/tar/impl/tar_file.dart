import 'dart:typed_data';

import '../../base/impl/exception.dart';
import '../../base/impl/input_stream.dart';
import '../../base/impl/output_stream.dart';
import '../../base/interface/input_stream.dart';
import '../../base/interface/output_stream.dart';
import '../interface/tar_file.dart';

class TarFileImpl implements TarFile {
  static const String TYPE_NORMAL_FILE = '0';
  static const String TYPE_HARD_LINK = '1';
  static const String TYPE_SYMBOLIC_LINK = '2';
  static const String TYPE_CHAR_SPEC = '3';
  static const String TYPE_BLOCK_SPEC = '4';
  static const String TYPE_DIRECTORY = '5';
  static const String TYPE_FIFO = '6';
  static const String TYPE_CONT_FILE = '7';

  // global extended header with meta data (POSIX.1-2001)
  static const String TYPE_G_EX_HEADER = 'g';
  static const String TYPE_G_EX_HEADER2 = 'G';

  // extended header with meta data for the next file in the archive
  // (POSIX.1-2001)
  static const String TYPE_EX_HEADER = 'x';
  static const String TYPE_EX_HEADER2 = 'X';

  @override
  late String filename;
  @override
  int mode = 644;
  @override
  int ownerId = 0;
  @override
  int groupId = 0;
  @override
  int fileSize = 0;
  @override
  int lastModTime = 0;
  @override
  int checksum = 0;
  @override
  String typeFlag = '0';
  @override
  late String nameOfLinkedFile;
  @override
  String ustarIndicator = '';
  @override
  String ustarVersion = '';
  @override
  String ownerUserName = '';
  @override
  String ownerGroupName = '';
  @override
  int deviceMajorNumber = 0;
  @override
  int deviceMinorNumber = 0;
  @override
  String filenamePrefix = '';
  InputStream? _rawContent;
  dynamic _content;

  TarFileImpl();

  TarFileImpl.read(InputStream input, {bool storeData = true}) {
    final header = input.readBytes(512);
    // The name, linkname, magic, uname, and gname are null-terminated
    // character strings. All other fields are zero-filled octal numbers in
    // ASCII. Each numeric field of width w contains w minus 1 digits, and a
    // null.
    filename = _parseString(header, 100);
    mode = _parseInt(header, 8);
    ownerId = _parseInt(header, 8);
    groupId = _parseInt(header, 8);
    fileSize = _parseInt(header, 12);
    lastModTime = _parseInt(header, 12);
    checksum = _parseInt(header, 8);
    typeFlag = _parseString(header, 1);
    nameOfLinkedFile = _parseString(header, 100);
    ustarIndicator = _parseString(header, 6);
    if (ustarIndicator == 'ustar') {
      ustarVersion = _parseString(header, 2);
      ownerUserName = _parseString(header, 32);
      ownerGroupName = _parseString(header, 32);
      deviceMajorNumber = _parseInt(header, 8);
      deviceMinorNumber = _parseInt(header, 8);
    }
    if (storeData || filename == '././@LongLink') {
      _rawContent = input.readBytes(fileSize);
    } else {
      input.skip(fileSize);
    }
    if (isFile && fileSize > 0) {
      final remainder = fileSize % 512;
      var skiplen = 0;
      if (remainder != 0) {
        skiplen = 512 - remainder;
        input.skip(skiplen);
      }
    }
  }

  @override
  bool get isFile => typeFlag != TYPE_DIRECTORY;

  @override
  bool get isSymLink => typeFlag == TYPE_SYMBOLIC_LINK;

  @override
  InputStream? get rawContent => _rawContent;

  @override
  dynamic get content => _content ??= _rawContent!.toUint8List();

  @override
  List<int> get contentBytes => content as List<int>;

  @override
  set content(dynamic data) => _content = data;

  @override
  int get size => _content != null
      // ignore: avoid_dynamic_calls
      ? _content.length as int
      : _rawContent != null
          ? _rawContent!.length
          : 0;

  @override
  String toString() => '[${filename}, ${mode}, ${fileSize}]';

  @override
  void write(dynamic output) {
    fileSize = size;
    // The name, linkname, magic, uname, and gname are null-terminated
    // character strings. All other fields are zero-filled octal numbers in
    // ASCII. Each numeric field of width w contains w minus 1 digits, and a null.
    final header = OutputStreamImpl();
    _writeString(header, filename, 100);
    _writeInt(header, mode, 8);
    _writeInt(header, ownerId, 8);
    _writeInt(header, groupId, 8);
    _writeInt(header, fileSize, 12);
    _writeInt(header, lastModTime, 12);
    _writeString(header, '        ', 8); // checksum placeholder
    _writeString(header, typeFlag, 1);
    final remainder = 512 - header.length;
    var nulls = Uint8List(remainder); // typed arrays default to 0.
    header.writeBytes(nulls);
    final headerBytes = header.getBytes();
    // The checksum is calculated by taking the sum of the unsigned byte values
    // of the header record with the eight checksum bytes taken to be ascii
    // spaces (decimal value 32). It is stored as a six digit octal number
    // with leading zeroes followed by a NUL and then a space.
    var sum = 0;
    for (final b in headerBytes) {
      sum += b;
    }
    var sum_str = sum.toRadixString(8); // octal basis
    while (sum_str.length < 6) {
      sum_str = '0' + sum_str;
    }
    var checksum_index = 148; // checksum is at 148th byte
    for (var i = 0; i < 6; ++i) {
      headerBytes[checksum_index++] = sum_str.codeUnits[i];
    }
    headerBytes[154] = 0;
    headerBytes[155] = 32;
    // ignore: avoid_dynamic_calls
    output.writeBytes(header.getBytes());
    if (_content != null) {
      // ignore: avoid_dynamic_calls
      output.writeBytes(_content);
    } else if (_rawContent != null) {
      // ignore: avoid_dynamic_calls
      output.writeInputStream(_rawContent);
    }
    if (isFile && fileSize > 0) {
      // Pad to 512-byte boundary
      final remainder = fileSize % 512;
      if (remainder != 0) {
        final skiplen = 512 - remainder;
        nulls = Uint8List(skiplen); // typed arrays default to 0.
        // ignore: avoid_dynamic_calls
        output.writeBytes(nulls);
      }
    }
  }

  int _parseInt(InputStreamImpl input, int numBytes) {
    final s = _parseString(input, numBytes);
    if (s.isEmpty) {
      return 0;
    }
    var x = 0;
    try {
      x = int.parse(s, radix: 8);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      // Catch to fix a crash with bad group_id and owner_id values.
      // This occurs for POSIX archives, where some attributes like uid and
      // gid are stored in a separate PaxHeader file.
    }
    return x;
  }

  String _parseString(InputStreamImpl input, int numBytes) {
    try {
      final codes = input.readBytes(numBytes);
      final r = codes.indexOf(0);
      final s = codes.subset(0, r < 0 ? null : r);
      final b = s.toUint8List();
      final str = String.fromCharCodes(b).trim();
      return str;
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      throw const ArchiveExceptionImpl('Invalid Archive');
    }
  }

  void _writeString(OutputStream output, String value, int numBytes) {
    final codes = List<int>.filled(numBytes, 0);
    final end = numBytes < value.length ? numBytes : value.length;
    codes.setRange(0, end, value.codeUnits);
    output.writeBytes(codes);
  }

  void _writeInt(OutputStreamImpl output, int value, int numBytes) {
    var s = value.toRadixString(8);
    while (s.length < numBytes - 1) {
      s = '0' + s;
    }
    _writeString(output, s, numBytes);
  }
}
