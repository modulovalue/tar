import '../../base/impl/archive_mixin.dart';
import '../../base/impl/input_stream.dart';
import '../../base/interface/archive.dart';
import '../../base/interface/file.dart';
import 'directory.dart';

/// Decode a zip formatted buffer into an [Archive] object.
abstract class ZipDecoder {
  ZipArchive decodeBytes(
    List<int> data, {
    bool verify,
    String? password,
  });

  ZipArchive decodeBuffer(
    InputStreamImpl input, {
    bool verify,
    String? password,
  });
}

abstract class ZipArchive<ARCHIVEFILE extends ArchiveFile> with ArchiveMixin<ARCHIVEFILE> {
  ZipDirectory get zipDirectory;
}
