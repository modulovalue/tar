/// The type flag of a header indicates the kind of file associated with the
/// entry. This enum contains the various type flags over the different TAR
/// formats, and users should be careful that the type flag corresponds to the
/// TAR format they are working with.
abstract class TypeFlag {
  int get flagByte;

  /// Indicates whether the file will have content.
  bool get hasContent;
}
