import 'dart:typed_data';

import '../../archive/interface/archive.dart';
import '../../archive/interface/file.dart';
import '../../base/interface/output_stream.dart';

/// Encode an [Archive] object into a tar formatted buffer.
abstract class TarEncoder {
  Uint8List encode(Archive archive);

  TarEncodingSession start(OutputStream output_stream);
}

abstract class TarEncodingSession {
  void add(ArchiveFile file);

  void finish();
}
