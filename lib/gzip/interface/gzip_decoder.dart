import 'dart:typed_data';

import '../../base/interface/input_stream.dart';
import '../../base/interface/output_stream.dart';

/// Decompress data with the gzip format decoder.
abstract class GZipDecoder {
  Uint8List decodeBytes(
    List<int> data, {
    bool verify = false,
  });

  void decodeStream(
    InputStream input,
    OutputStream output,
  );

  Uint8List decodeBuffer(
    InputStream input, {
    bool verify = false,
  });
}
