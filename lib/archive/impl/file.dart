import '../../base/impl/input_stream.dart';
import 'constants.dart';
import 'file_mixin.dart';

/// A file contained in an Archive.
class ArchiveFileImpl with ArchiveFileMixin {
  @override
  final int uncompressedSizeOfTheFile;
  @override
  final String name;
  @override
  int? compressionType;

  ArchiveFileImpl(String name, this.uncompressedSizeOfTheFile, dynamic content, [this.compressionType = ARCHIVE_STORE])
      : this.name = name.replaceAll('\\', '/') {
    if (content is List<int>) {
      content_ = content;
      rawContent = InputStreamImpl(content_);
    } else if (content is InputStreamImpl) {
      rawContent = InputStreamImpl.from(content);
    }
  }

  ArchiveFileImpl.noCompress(String name, this.uncompressedSizeOfTheFile, dynamic content) : this.name = name.replaceAll('\\', '/') {
    compress = false;
    if (content is List<int>) {
      content_ = content;
      rawContent = InputStreamImpl(content_);
    } else if (content is InputStreamImpl) {
      rawContent = InputStreamImpl.from(content);
    }
  }

  ArchiveFileImpl.stream(String name, this.uncompressedSizeOfTheFile, dynamic content_stream)
      : compressionType = ARCHIVE_STORE,
        // Paths can only have / path separators
        this.name = name.replaceAll('\\', '/') {
    compress = true;
    content_ = content_stream;
  }
}
