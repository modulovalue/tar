import 'dart:io';

import 'package:path/path.dart' as path;

import '../archive/impl/archive.dart';
import '../archive/impl/file.dart';
import '../archive/interface/archive.dart';
import '../io/impl/input_file_stream.dart';

Archive createArchiveFromDirectory(Directory dir, {bool includeDirName = true}) {
  final archive = ArchiveImpl();
  final dir_name = path.basename(dir.path);
  final files = dir.listSync(recursive: true);
  for (final file in files) {
    if (file is File) {
      final f = file;
      final filename = () {
        final _filename = path.relative(f.path, from: dir.path);
        if (includeDirName) {
          return dir_name + '/' + _filename;
        } else {
          return _filename;
        }
      }();
      final file_stream = InputFileStreamImpl.file(f);
      final af = ArchiveFileImpl.stream(filename, f.lengthSync(), file_stream);
      af.lastModTime = f.lastModifiedSync().millisecondsSinceEpoch;
      af.mode = f.statSync().mode;
      archive.addFile(af);
    }
  }
  return archive;
}
