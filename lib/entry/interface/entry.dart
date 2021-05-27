import 'dart:async';

import '../../constants.dart';
import '../../header/interface/header.dart';

/// An entry in a tar file.
///
/// Usually, tar entries are read from a stream, and they're bound to the stream
/// from which they've been read. This means that they can only be read once,
/// and that only one [TarEntry] is active at a time.
abstract class TarEntry {
  /// The parsed [TarHeader] of this tar entry.
  TarHeader get header;

  /// The content stream of the active tar entry.
  ///
  /// For tar entries read through the reader provided by this library,
  /// [contents] is a single-subscription streamed backed by the original stream
  /// used to create the reader.
  /// When listening on [contents], the stream needs to be fully drained before
  /// the next call to [StreamIterator.moveNext]. It's acceptable to not listen
  /// to [contents] at all before calling [StreamIterator.moveNext] again.
  /// In that case, this library will take care of draining the stream to get to
  /// the next entry.
  Stream<List<int>> get contents;

  /// The name of this entry, as indicated in the header or a previous pax
  /// entry.
  String get name;

  /// The type of tar entry (file, directory, etc.).
  TypeFlag get type;

  /// The content size of this entry, in bytes.
  int get size;

  /// Time of the last modification of this file, as indicated in the [header].
  DateTime get modified;
}
