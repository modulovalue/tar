import 'dart:typed_data';

/// Compress data using the BZip2 format.
/// Derived from libbzip2 (http://www.bzip.org).
abstract class BZip2Encoder {
  Uint8List encode(List<int> data);
}
