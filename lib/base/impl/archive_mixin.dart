import '../interface/archive.dart';
import '../interface/file.dart';

mixin ArchiveMixin<ARCHIVEFILE extends ArchiveFile> implements Archive<ARCHIVEFILE> {
  /// The list of files in the archive.
  List<ARCHIVEFILE> get files;

  @override
  String? get comment;

  @override
  void addFile(ARCHIVEFILE file) => files.add(file);

  @override
  ARCHIVEFILE operator [](int index) => files[index];

  @override
  ARCHIVEFILE? findFile(String name) {
    for (final f in files) {
      if (f.name == name) {
        return f;
      }
    }
    return null;
  }

  @override
  int numberOfFiles() => files.length;

  @override
  String fileName(int index) => files[index].name;

  @override
  int fileSize(int index) => files[index].uncompressedSizeOfTheFile;

  @override
  List<int> fileData(int index) => files[index].content as List<int>;

  @override
  ARCHIVEFILE get first => files.first;

  @override
  ARCHIVEFILE get last => files.last;

  @override
  bool get isEmpty => files.isEmpty;

  @override
  bool get isNotEmpty => files.isNotEmpty;

  @override
  Iterable<ARCHIVEFILE> get iterable => files;
}
