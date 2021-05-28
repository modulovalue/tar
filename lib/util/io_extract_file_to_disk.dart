import 'dart:io';

import '../archive/interface/archive.dart';

void extractArchiveToDisk(Archive archive, String outputPath) {
  final outDir = Directory(outputPath);
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }
  for (final file in archive.iterable) {
    if (file.isFile) {
      final f = File('${outputPath}${Platform.pathSeparator}${file.name}');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(file.content as List<int>);
    }
  }
}
