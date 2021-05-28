import 'dart:async';

import 'entry.dart';
import 'header.dart';

/// Creates a stream transformer writing tar entries as byte streams, with
/// custom encoding options.
///
/// The [format] [OutputFormat] can be used to select the way tar entries with
/// long file or link names are written. By default, the writer will emit an
/// extended PAX header for the file ([OutputFormat.pax]).
/// Alternatively, [OutputFormat.gnuLongName] can be used to emit special tar
/// entries with the gnuLongName type.
///
/// Regardless of the input stream, the stream returned by this
/// [StreamTransformer.bind] is a single-subscription stream.
/// Apart from that, subscriptions, cancellations, pauses and resumes are
/// propagated as one would expect from a [StreamTransformer].
///
/// When piping the resulting stream into a [StreamConsumer], consider using
/// [TarEncoderSink] directly.
abstract class TarEncoderTransformer extends StreamTransformerBase<TarEntry, List<int>> {
  OutputFormat get format;
}

/// Create a sink emitting encoded tar files to the given sink.
///
/// For instance, you can use this to write a tar file:
///
/// ```dart
/// import 'dart:convert';
/// import 'dart:io';
/// import 'package:tar/tar.dart';
///
/// Future<void> main() async {
///   Stream<TarEntry> entries = Stream.value(
///     TarEntry.data(
///       TarHeader(
///         name: 'example.txt',
///         mode: int.parse('644', radix: 8),
///       ),
///       utf8.encode('This is the content of the tar file'),
///     ),
///   );
///
///   final output = File('/tmp/test.tar').openWrite();
///   await entries.pipe(tarWritingSink(output));
///  }
/// ```
///
/// Note that, if you don't set the [TarHeader.size], outgoing tar entries need
/// to be buffered once, which decreases performance.
///
/// The given argument can be used to control how long file names are written
/// in the tar archive. For more details, see the options in [OutputFormat].
///
/// See also:
///  - [TarEncoderTransformer], a stream transformer using this sink
///  - [StreamSink]
abstract class TarEncoderSink extends StreamSink<TarEntry> {
  OutputFormat get format;
}

/// This option controls how long file and link names should be written.
///
/// This option can be passed to writer in [TarEncoderSink] or [TarEncoderTransformer].
enum OutputFormat {
  /// Generates an extended PAX headers to encode files with a long name.
  ///
  /// This is the default option.
  pax,

  /// Generates gnuLongName or gnuLongLink entries when
  /// encoding files with a long name.
  ///
  /// When this option is set, `package:tar` will not emit PAX headers which
  /// may improve compatibility with some legacy systems like old 7zip versions.
  ///
  /// Note that this format can't encode large file sizes or long user names.
  /// Tar entries can't be written if
  ///  * their [TarHeader.userName] is longer than 31 bytes in utf8,
  ///  * their [TarHeader.groupName] is longer than 31 bytes in utf8, or,
  ///  * their [TarEntry.contents] are larger than 8589934591 byte (around
  ///    8 GiB).
  ///
  /// Attempting to encode such file will throw an [UnsupportedError].
  gnuLongName,
}
