import '../../base/interface/input_stream.dart';

abstract class InputFileStream implements InputStream {
  String get path;

  int get byteOrder;

  void close();

  int get bufferSize;

  int get bufferPosition;

  int get bufferRemaining;

  int get fileRemaining;
}
