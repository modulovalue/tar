import 'package:meta/meta.dart';

/// An exception indicating that there was an issue parsing a `.tar` file.
/// Intended to be seen by the user.
class TarException extends FormatException {
  @override
  // ignore: overridden_fields, overridden because FormatException doesn't have a mixin.
  final String message;

  @internal
  const TarException(this.message) : super(message);

  @internal
  const TarException.header(String message) : this.message = 'Invalid header: $message';
}
