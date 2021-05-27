import '../../format/interface/format.dart';
import '../../type_flag/interface/flag.dart';

/// Header of a tar entry
///
/// A tar header stores meta-information about the matching tar entry, such as
/// its name.
abstract class TarHeader {
  /// Type of header entry. In the V7 TAR format, this field was known as the
  /// link flag.
  TypeFlag get typeFlag;

  /// Name of file or directory entry.
  String get name;

  /// Target name of link (valid for hard links or symbolic links).
  String? get linkName;

  /// Permission and mode bits.
  int get mode;

  /// User ID of owner.
  int get userId;

  /// Group ID of owner.
  int get groupId;

  /// User name of owner.
  String? get userName;

  /// Group name of owner.
  String? get groupName;

  /// Logical file size in bytes.
  int get size;

  /// The time of the last change to the data of the TAR file.
  DateTime get modified;

  /// The time of the last access to the data of the TAR file.
  DateTime? get accessed;

  /// The time of the last change to the data or metadata of the TAR file.
  DateTime? get changed;

  /// Major device number
  int get devMajor;

  /// Minor device number
  int get devMinor;

  /// The TAR format of the header.
  TarFormat get format;
}
