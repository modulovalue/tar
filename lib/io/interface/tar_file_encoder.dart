import 'dart:io';

abstract class TarFileEncoder {
  String get tar_path;

  void tarDirectory(
    Directory dir, {
    int compression,
    String? filename,
  });

  void open(String tar_path);

  void create(String tar_path);

  void addDirectory(Directory dir);

  void addFile(File file, [String? filename]);

  void close();
}
