import '../../archive/interface/archive.dart';
import '../../archive/interface/file.dart';
import '../../base/interface/input_stream.dart';
import 'tar_file.dart';

/// Decode a tar formatted buffer into an [Archive] object.
abstract class TarDecoder {
  Archive decodeBytes(
    List<int> data, {
    bool verify,
    bool storeData,
  });

  Archive<TarArchiveFile> decodeBuffer(
    InputStream input, {
    bool verify,
    bool storeData,
  });
}

abstract class TarArchiveFile implements ArchiveFile {
  TarFile get tarFile;
}
