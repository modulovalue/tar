import 'dart:convert';

import '../../base/constants.dart';
import '../../base/tar_exception.dart';
import '../interface/pax_headers.dart';

class PaxHeadersImpl implements PaxHeaders {
  final Map<String, String> _globalHeaders;
  final Map<String, String> _localHeaders;

  PaxHeadersImpl(this._globalHeaders, this._localHeaders); // Not const because headers are mutable.

  factory PaxHeadersImpl.empty() => PaxHeadersImpl({}, {});

  @override
  void forEach(void Function(String key, String value) fn) {
    _globalHeaders.forEach(fn);
    _localHeaders.forEach(fn);
  }

  /// Applies new global PAX-headers from the map.
  ///
  /// The [headers] will replace global headers with the same key, but leave
  /// others intact.
  @override
  void newGlobals(Map<String, String> headers) => _globalHeaders.addAll(headers);

  @override
  void addLocal(String key, String value) => _localHeaders[key] = value;

  @override
  void removeLocal(String key) => _localHeaders.remove(key);

  /// Applies new local PAX-headers from the map.
  ///
  /// This replaces all currently active local headers.
  @override
  void newLocals(Map<String, String> headers) => _localHeaders
    ..clear()
    ..addAll(headers);

  /// Clears local headers.
  ///
  /// This is used by the reader after a file has ended, as local headers only
  /// apply to the next entry.
  @override
  void clearLocals() => _localHeaders.clear();

  @override
  String? get(Object? key) => _localHeaders[key] ?? _globalHeaders[key];

  @override
  Iterable<String> get keys => {..._globalHeaders.keys, ..._localHeaders.keys};

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
  @override
  void readPaxHeaders(List<int> data, bool isGlobal, bool ignoreUnknown) {
    var offset = 0;
    final map = <String, String>{};
    final sparseMap = <String>[];
    while (offset < data.length) {
      // At the start of an entry, expect its length which is terminated by a
      // space char.
      final space = data.indexOf($space, offset);
      if (space == -1) {
        break;
      } else {
        var length = 0;
        var currentChar = data[offset];
        var charsInLength = 0;
        while (currentChar >= $char0 && currentChar <= $char9) {
          length = length * 10 + currentChar - $char0;
          charsInLength++;
          currentChar = data[++offset];
        }
        if (length == 0) {
          throw const TarExceptionInvalidPAXRecordImpl('Invalid header: invalid PAX record');
        } else {
          // Skip the whitespace
          if (currentChar != $space) {
            throw const TarExceptionInvalidPAXRecordImpl('Invalid header: invalid PAX record');
          } else {
            offset++;
            // Length also includes the length description and a space we just read
            final endOfEntry = offset + length - 1 - charsInLength;
            // checking against endOfEntry - 1 because the trailing whitespace is
            // optional for the last entry
            if (endOfEntry < offset || endOfEntry - 1 > data.length) {
              throw const TarExceptionInvalidPAXRecordImpl('Invalid header: invalid PAX record');
            } else {
              // Read the key
              final nextEquals = data.indexOf($equal, offset);
              if (nextEquals == -1 || nextEquals >= endOfEntry) {
                throw const TarExceptionInvalidPAXRecordImpl('Invalid header: invalid PAX record');
              } else {
                final key = const Utf8Decoder().convert(data, offset, nextEquals);
                // Skip over the equals sign
                offset = nextEquals + 1;
                // Subtract one for trailing newline
                final endOfValue = endOfEntry - 1;
                final value = const Utf8Decoder().convert(data, offset, endOfValue);
                if (!_isValidPaxRecord(key, value)) {
                  throw const TarExceptionInvalidPAXRecordImpl('Invalid header: invalid PAX record');
                } else {
                  // If we're seeing weird PAX Version 0.0 sparse keys, expect alternating
                  // GNU.sparse.offset and GNU.sparse.numbytes headers.
                  if (key == paxGNUSparseNumBytes || key == paxGNUSparseOffset) {
                    if ((sparseMap.length.isEven && key != paxGNUSparseOffset) ||
                        (sparseMap.length.isOdd && key != paxGNUSparseNumBytes) ||
                        value.contains(',')) {
                      throw const TarExceptionInvalidPAXRecordImpl('Invalid header: invalid PAX record');
                    } else {
                      sparseMap.add(value);
                    }
                  } else if (!ignoreUnknown || supportedPaxHeaders.contains(key)) {
                    // Ignore unrecognized headers to avoid unbounded growth of the global
                    // header map.
                    map[key] = value;
                  }
                  // Skip over value
                  offset = endOfValue;
                  // and the trailing newline
                  final hasNewline = offset < data.length;
                  if (hasNewline && data[offset] != $lf) {
                    throw const TarExceptionInvalidPAXRecordImpl('Invalid PAX Record (missing trailing newline)');
                  } else {
                    offset++;
                  }
                }
              }
            }
          }
        }
      }
      if (sparseMap.isNotEmpty) {
        map[paxGNUSparseMap] = sparseMap.join(',');
      }
      if (isGlobal) {
        newGlobals(map);
      } else {
        newLocals(map);
      }
    }
  }

  /// Checks whether [key], [value] is a valid entry in a pax header.
  ///
  /// This is adopted from the Golang tar reader (`validPAXRecord`), which says
  /// that "Keys and values should be UTF-8, but the number of bad writers out
  /// there forces us to be a more liberal."
  static bool _isValidPaxRecord(String key, String value) {
    // These limitations are documented in the PAX standard.
    if (key.isEmpty || key.contains('=')) {
      return false;
    } else {
      // These aren't, but Golangs's tar has them and got away with it.
      switch (key) {
        case paxPath:
        case paxLinkpath:
        case paxUname:
        case paxGname:
          return !value.codeUnits.contains(0);
        default:
          return !key.codeUnits.contains(0);
      }
    }
  }

  @override
  int? get size {
    final sizeStr = this.get(paxSize);
    if (sizeStr == null) {
      // ignore: avoid_returning_null
      return null;
    } else {
      return int.tryParse(sizeStr);
    }
  }
}

class TarExceptionInvalidPAXRecordImpl extends FormatException implements TarException {
  const TarExceptionInvalidPAXRecordImpl(String message) : super(message);
}
