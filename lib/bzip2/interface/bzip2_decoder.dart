import 'dart:typed_data';

import '../../base/interface/input_stream.dart';
import '../../base/interface/output_stream.dart';

/// Decompress bzip2 compressed data.
/// Derived from libbzip2 (http://www.bzip.org).
abstract class BZip2Decoder {
  Uint8List decodeBytes(
    List<int> data, {
    bool verify = false,
  });

  Uint8List decodeBuffer(
    InputStream _input, {
    bool verify = false,
    OutputStream? output,
  });
}
