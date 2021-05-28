import '../../base/impl/input_stream.dart';
import '../../zlib/impl/inflate.dart';
import '../interface/file.dart';
import 'constants.dart';

/// A file contained in an Archive.
mixin ArchiveFileMixin implements ArchiveFile {
  @override
  int mode = 420; // octal 644 (-rw-r--r--)
  @override
  int ownerId = 0;
  @override
  int groupId = 0;
  @override
  int lastModTime = 0;
  @override
  bool isFile = true;
  @override
  bool isSymbolicLink = false;
  @override
  String nameOfLinkedFile = '';
  @override
  InputStreamImpl? rawContent;
  dynamic content_;
  @override
  int? crc32;
  @override
  String? comment;
  @override
  bool compress = true;

  @override
  int get unixPermissions => mode & 0x1FF;

  set compressionType(int? setCompressionType);

  @override
  dynamic get content {
    if (content_ == null) {
      decompress();
    }
    return content_;
  }

  @override
  void decompress() {
    if (content_ == null && rawContent != null) {
      if (compressionType == ARCHIVE_DEFLATE) {
        content_ = InflateImpl.buffer(rawContent!, uncompressedSizeOfTheFile).getBytes();
      } else {
        content_ = rawContent!.toUint8List();
      }
      compressionType = ARCHIVE_STORE;
    }
  }

  @override
  bool get isCompressed => compressionType != ARCHIVE_STORE;

  @override
  String toString() => name;
}
