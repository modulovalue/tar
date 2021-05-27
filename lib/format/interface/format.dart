abstract class TarFormat {
  /// The TAR formats are encoded in powers of two in [value], such that we
  /// can refine our guess via bit operations as we discover more information
  /// about the TAR file.
  int get value;

  /// Returns if [other] is a possible resolution of `this`.
  ///
  /// For example, a [TarFormat] with a value of 6 means that we do not have
  /// enough information to determine if it is ustar or
  /// pax, so either of them could be possible resolutions of
  /// `this`.
  bool has(TarFormat other);

  /// Returns a new [TarFormat] that signifies that it can be either
  /// `this` or [other]'s format.
  ///
  /// **Example:**
  /// ```dart
  /// TarFormat format = TarFormat.USTAR | TarFormat.PAX;
  /// ```
  ///
  /// The above code would signify that we have limited `format` to either
  /// the USTAR or PAX format, but need further information to refine the guess.
  TarFormat operator |(TarFormat other);

  /// Returns a new [TarFormat] that signifies that it can be either
  /// `this` or [other]'s format.
  ///
  /// **Example:**
  /// ```dart
  /// TarFormat format = TarFormat.PAX;
  /// format = format.mayBe(TarFormat.USTAR);
  /// ```
  ///
  /// The above code would signify that we learnt that in addition to being a
  /// PAX format, it could also be of the USTAR format.
  TarFormat mayBe(TarFormat? other);

  /// Returns a new [TarFormat] that signifies that it can only be [other]'s
  /// format.
  ///
  /// **Example:**
  /// ```dart
  /// TarFormat format = TarFormat.PAX | TarFormat.USTAR;
  /// ...
  /// format = format.mayOnlyBe(TarFormat.USTAR);
  /// ```
  ///
  /// In the above example, we found that `format` could either be PAX or USTAR,
  /// but later learnt that it can only be the USTAR format.
  ///
  /// If `has(other) == false`, [mayOnlyBe] will result in an unknown
  /// [TarFormat].
  TarFormat mayOnlyBe(TarFormat other);

  /// Returns if this format might be valid.
  ///
  /// This returns true as well even if we have yet to fully determine what the
  /// format is.
  bool isValid();
}
