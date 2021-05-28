import 'header.dart';

abstract class ZipDirectory {
  int get filePosition;

  // 2 bytes
  int get numberOfThisDisk;

  // 2 bytes
  int get diskWithTheStartOfTheCentralDirectory;

  // 2 bytes
  int get totalCentralDirectoryEntriesOnThisDisk;

  // 2 bytes
  int get totalCentralDirectoryEntries;

  // 4 bytes
  int get centralDirectorySize;

  // 2 bytes
  int get centralDirectoryOffset;

  // 2 bytes, n bytes
  String get zipFileComment;

  // Central Directory
  List<ZipFileHeader> get fileHeaders;
}
