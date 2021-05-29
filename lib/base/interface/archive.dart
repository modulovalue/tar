import 'file.dart';

/// A collection of files
abstract class Archive<ARCHIVEFILE extends ArchiveFile> {
  String? get comment;

  /// Add a file to the archive.
  void addFile(ARCHIVEFILE file);

  /// Get a file from the archive.
  ARCHIVEFILE operator [](int index);

  /// Find a file with the given [name] in the archive. If the file isn't found,
  /// null will be returned.
  ARCHIVEFILE? findFile(String name);

  /// The number of files in the archive.
  int numberOfFiles();

  /// The name of the file at the given [index].
  String fileName(int index);

  /// The decompressed size of the file at the given [index].
  int fileSize(int index);

  /// The decompressed data of the file at the given [index].
  List<int> fileData(int index);

  ARCHIVEFILE get first;

  ARCHIVEFILE get last;

  bool get isEmpty;

  bool get isNotEmpty;

  Iterable<ARCHIVEFILE> get iterable;
}
