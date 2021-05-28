import 'dart:math';

import '../interface/tar_exception.dart';
import 'us_since_epoch.dart';

/// Takes a [paxTimeString] of the form %d.%d as described in the PAX
/// specification. Note that this implementation allows for negative timestamps,
/// which is allowed for by the PAX specification, but not always portable.
///
/// Note that Dart's [DateTime] class only allows us to give up to microsecond
/// precision, which implies that we cannot parse all the digits in since PAX
/// allows for nanosecond level encoding.
DateTime parsePaxTime(String paxTimeString) {
  const maxMicroSecondDigits = 6;
  // Split [paxTimeString] into seconds and sub-seconds parts.
  var secondsString = paxTimeString;
  var microSecondsString = '';
  final position = paxTimeString.indexOf('.');
  if (position >= 0) {
    secondsString = paxTimeString.substring(0, position);
    microSecondsString = paxTimeString.substring(position + 1);
  }
  // Parse the seconds.
  final seconds = int.tryParse(secondsString);
  if (seconds == null) {
    throw TarExceptionInvalidHeaderBecauseInvalidPaxTimeImpl('Invalid header: invalid PAX time $paxTimeString detected!');
  } else {
    if (microSecondsString.replaceAll(RegExp('[0-9]'), '') != '') {
      throw TarExceptionInvalidHeaderBecauseInvalidNanosecondsImpl('Invalid header: invalid nanoseconds $microSecondsString detected');
    } else {
      microSecondsString = microSecondsString.padRight(maxMicroSecondDigits, '0');
      microSecondsString = microSecondsString.substring(0, maxMicroSecondDigits);
      var microSeconds = microSecondsString.isEmpty ? 0 : int.parse(microSecondsString);
      if (paxTimeString.startsWith('-')) {
        microSeconds = -microSeconds;
      }
      return microsecondsSinceEpoch(microSeconds + seconds * pow(10, 6).toInt());
    }
  }
}

abstract class TarExceptionInvalidTime implements TarException {}

class TarExceptionInvalidHeaderBecauseInvalidNanosecondsImpl extends FormatException implements TarExceptionInvalidTime {
  const TarExceptionInvalidHeaderBecauseInvalidNanosecondsImpl(String message) : super(message);
}

class TarExceptionInvalidHeaderBecauseInvalidPaxTimeImpl extends FormatException implements TarExceptionInvalidTime {
  const TarExceptionInvalidHeaderBecauseInvalidPaxTimeImpl(String message) : super(message);
}
