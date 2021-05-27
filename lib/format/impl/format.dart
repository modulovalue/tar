import '../interface/format.dart';

/// Handy map to help us translate [TarFormat] values to their names.
/// Be sure to keep this consistent with the constant initializers in
/// [TarFormat].
const _formatNames = {1: 'V7', 2: 'USTAR', 4: 'PAX', 8: 'GNU', 16: 'STAR'};

/// Holds the possible TAR formats that a file could take.
///
/// This library only supports the V7, USTAR, PAX, GNU, and STAR formats.
class TarFormatImpl implements TarFormat {
  @override
  final int value;

  const TarFormatImpl(this.value);

  @override
  int get hashCode => value;

  @override
  bool operator ==(Object? other) => other is TarFormat && value == other.value;

  @override
  String toString() {
    if (!isValid()) {
      return 'Invalid';
    } else {
      final possibleNames = _formatNames //
          .entries
          .where((e) => value & e.key != 0)
          .map((e) => e.value);
      return possibleNames.join(' or ');
    }
  }

  @override
  bool has(TarFormat other) => value & other.value != 0;

  @override
  TarFormat operator |(TarFormat other) => mayBe(other);

  @override
  TarFormat mayBe(TarFormat? other) {
    if (other == null) {
      return this;
    } else {
      return TarFormatImpl(value | other.value);
    }
  }

  @override
  TarFormat mayOnlyBe(TarFormat other) => TarFormatImpl(value & other.value);

  @override
  bool isValid() => value > 0;
}
