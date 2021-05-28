import 'dart:io' hide GZIP;

import '../../archive/interface/file.dart';

abstract class ZipFileEncoder {
  String get zip_path;

  void zipDirectory(Directory dir, {String? filename, int? level});

  void open(String zip_path);

  void create(String zip_path_, {int? level});

  void addDirectory(Directory dir, {bool includeDirName = true, int? level});

  void addFile(File file, [String? filename, int? level]);

  void addArchiveFile(ArchiveFile file);

  void close();
}
