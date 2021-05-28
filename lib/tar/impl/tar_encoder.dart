import 'dart:typed_data';

import '../../archive/interface/archive.dart';
import '../../archive/interface/file.dart';
import '../../base/impl/output_stream.dart';
import '../../base/interface/output_stream.dart';
import '../interface/tar_encoder.dart';
import 'tar_file.dart';

class TarEncoderImpl implements TarEncoder {
  const TarEncoderImpl();

  @override
  Uint8List encode(Archive archive) {
    final output_stream = OutputStreamImpl();
    final session = start(output_stream);
    archive.iterable.forEach(session.add);
    session.finish();
    return output_stream.getBytes();
  }

  @override
  TarEncodingSession start(OutputStream output_stream) => //
      TarEncodingSessionImpl(output_stream);
}

class TarEncodingSessionImpl implements TarEncodingSession {
  dynamic _output_stream;

  TarEncodingSessionImpl(this._output_stream);

  @override
  void add(ArchiveFile file) {
    if (_output_stream != null) {
      // GNU tar files store extra long file names in a separate file
      if (file.name.length > 100) {
        final ts = TarFileImpl();
        ts.filename = '././@LongLink';
        ts.fileSize = file.name.length;
        ts.mode = 0;
        ts.ownerId = 0;
        ts.groupId = 0;
        ts.lastModTime = 0;
        ts.content = file.name.codeUnits;
        ts.write(_output_stream);
      }
      final ts = TarFileImpl();
      ts.filename = file.name;
      ts.fileSize = file.uncompressedSizeOfTheFile;
      ts.mode = file.mode;
      ts.ownerId = file.ownerId;
      ts.groupId = file.groupId;
      ts.lastModTime = file.lastModTime;
      ts.content = file.content;
      ts.write(_output_stream);
    }
  }

  @override
  void finish() {
    // At the end of the archive file there are two 512-byte blocks filled
    // with binary zeros as an end-of-file marker.
    final eof = Uint8List(1024);
    // ignore: avoid_dynamic_calls
    _output_stream.writeBytes(eof);
    _output_stream = null;
  }
}
