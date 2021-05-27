import 'dart:async';

import '../../entry/interface/entry.dart';

/// [TarDecoder] provides sequential access to the TAR files in a TAR archive.
/// It is designed to read from a stream and to spit out substreams for
/// individual file contents in order to minimize the amount of memory needed
/// to read each archive where possible.
abstract class TarDecoder implements StreamIterator<TarEntry> {}
