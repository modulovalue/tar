import 'dart:typed_data';

import '../../base/interface/input_stream.dart';

abstract class Inflate {
  InputStream get input;

  void streamInput(List<int> bytes);

  List<int>? inflateNext();

  /// Get the decompressed data.
  Uint8List getBytes();
}
