import '../../archive/impl/archive_mixin.dart';
import '../../archive/interface/archive.dart';
import '../../archive/interface/file.dart';
import '../../base/impl/input_stream.dart';
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
