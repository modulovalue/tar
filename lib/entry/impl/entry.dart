import 'dart:async';

import '../../constants.dart';
import '../../header/interface/header.dart';
import '../interface/entry.dart';

class TarEntryImpl implements TarEntry {
  @override
  final TarHeader header;

  @override
  final Stream<List<int>> contents;

  @override
  String get name => header.name;

  @override
  TypeFlag get type => header.typeFlag;

  @override
  int get size => header.size;

  @override
  DateTime get modified => header.modified;

  /// Creates a tar entry from a [header] and the [contents] stream.
  ///
  /// If the total length of [contents] is known, consider setting the
  /// [header]'s [TarHeader.size] property to the appropriate value.
  /// Otherwise, the tar writer needs to buffer contents to determine the right
  /// size.
  const TarEntryImpl(this.header, this.contents);
}
