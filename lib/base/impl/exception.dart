/// An exception thrown when there was a problem in the archive library.
/// TODO this exception should be replaced by a custom exception for each use of this.
class ArchiveExceptionImpl extends FormatException {
  const ArchiveExceptionImpl(
    String message, [
    dynamic source,
    int? offset,
  ]) : super(message, source, offset);
}
