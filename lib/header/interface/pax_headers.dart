
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
