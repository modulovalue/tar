import 'dart:io';

abstract class TarCommand {
  void tarCommand(List<String> arguments);

  void createTarFile(String dirPath);

  /// Print the entries in the given tar file.
  void listFiles(String path);

  /// Extract the entries in the given tar file to a directory.
  Directory extractFiles(String inputPath, String outputPath);
}
