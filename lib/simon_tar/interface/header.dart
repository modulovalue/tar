import 'flag.dart';
import 'format.dart';

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


abstract class PaxHeaders {
  void forEach(void Function(String key, String value) fn);

  /// Applies new global PAX-headers from the map.
  ///
  /// The [headers] will replace global headers with the same key, but leave
  /// others intact.
  void newGlobals(Map<String, String> headers);

  void addLocal(String key, String value);

  void removeLocal(String key);

  /// Applies new local PAX-headers from the map.
  ///
  /// This replaces all currently active local headers.
  void newLocals(Map<String, String> headers);

  /// Clears local headers.
  ///
  /// This is used by the reader after a file has ended, as local headers only
  /// apply to the next entry.
  void clearLocals();

  String? get(Object? key);

  Iterable<String> get keys;

  /// Decodes the content of an extended pax header entry.
  ///
  /// Semantically, a [PAX Header][posix pax] is a map with string keys and
  /// values, where both keys and values are encodes with utf8.
  ///
  /// However, [old GNU Versions][gnu sparse00] used to repeat keys to store
  /// sparse file information in sparse headers. This method will transparently
  /// rewrite the PAX format of version 0.0 to version 0.1.
  ///
  /// [posix pax]: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html#tag_20_92_13_03
  /// [gnu sparse00]: https://www.gnu.org/software/tar/manual/html_section/tar_94.html#SEC192
  void readPaxHeaders(List<int> data, bool isGlobal, bool ignoreUnknown);

  int? get size;
}
