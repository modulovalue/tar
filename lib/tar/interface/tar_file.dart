import '../../base/interface/input_stream.dart';

/// File Header (512 bytes)
/// Offst Size Field
///     Pre-POSIX Header
/// 0     100  File name
/// 100   8    File mode
/// 108   8    Owner's numeric user ID
/// 116   8    Group's numeric user ID
/// 124   12   File size in bytes (octal basis)
/// 136   12   Last modification time in numeric Unix time format (octal)
/// 148   8    Checksum for header record
/// 156   1    Type flag
/// 157   100  Name of linked file
///     UStar Format
/// 257   6    UStar indicator "ustar"
/// 263   2    UStar version "00"
/// 265   32   Owner user name
/// 297   32   Owner group name
/// 329   8    Device major number
/// 337   8    Device minor number
/// 345   155  Filename prefix
abstract class TarFile implements UStarFormat {
  // 100 bytes
  String get filename;

  // 8 bytes
  int get mode;

  // 8 bytes
  int get ownerId;

  // 8 bytes
  int get groupId;

  // 12 bytes
  int get fileSize;

  // 12 bytes
  int get lastModTime;

  // 8 bytes
  int get checksum;

  // 1 byte
  String get typeFlag;

  // 100 bytes
  String get nameOfLinkedFile;

  // 32 bytes
  String get ownerUserName;

  // 32 bytes
  String get ownerGroupName;

  // 8 bytes
  int get deviceMajorNumber;

  // 8 bytes
  int get deviceMinorNumber;

  // 155 bytes
  String get filenamePrefix;

  bool get isFile;

  bool get isSymLink;

  InputStream? get rawContent;

  dynamic get content;

  List<int> get contentBytes;

  set content(dynamic data);

  int get size;

  void write(dynamic output);
}

abstract class UStarFormat {
  // 6 bytes (ustar)
  String get ustarIndicator;

  // 2 bytes (00)
  String get ustarVersion;
}
