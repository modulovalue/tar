import '../tar_exception.dart';

/// Like [int.parse], but throwing a [TarException] instead of the more-general
/// [FormatException] when it fails.
int parseInt(
  String source,
) =>
    int.tryParse(source, radix: 10) ?? (throw TarExceptionNotAnInt('Not an int: $source'));

class TarExceptionNotAnInt extends FormatException implements TarException {
  const TarExceptionNotAnInt(String message) : super(message);
}
