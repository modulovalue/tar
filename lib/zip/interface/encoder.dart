import '../../archive/interface/archive.dart';
import '../../archive/interface/file.dart';
import '../../base/interface/output_stream.dart';

/// Encode an [Archive] object into a Zip formatted buffer.
abstract class ZipEncoder {
  List<int>? encode(
    Archive archive, {
    int level,
    OutputStream? output,
    DateTime? modified,
  });

  ZipEncodingSession startEncode(
    OutputStream? output, {
    int? level,
    DateTime? modified,
  });
}

abstract class ZipEncodingSession {
  int getFileCrc32(ArchiveFile file);

  void addFile(ArchiveFile file);

  void endEncode({String? comment = ''});
}
