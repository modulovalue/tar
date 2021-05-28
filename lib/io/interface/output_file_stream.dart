import '../../base/interface/output_stream.dart';

abstract class OutputFileStream implements OutputStream {
  String get path;

  void close();

  List<int> subset(int start, [int? end]);
}
