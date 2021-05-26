// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This was inlined from package:async to remove that dependency.

import 'dart:async';
import 'dart:typed_data';

class ChunkedStreamReader<T> {
  final StreamIterator<List<T>> _input;
  final List<T> _emptyList = const [];
  List<T> _buffer = <T>[];
  bool _reading = false;

  factory ChunkedStreamReader(Stream<List<T>> stream) => ChunkedStreamReader._(StreamIterator(stream));

  ChunkedStreamReader._(this._input);

  /// Read next [size] elements from _chunked stream_, buffering to create a
  /// chunk with [size] elements.
  ///
  /// This will read _chunks_ from the underlying _chunked stream_ until [size]
  /// elements have been buffered, or end-of-stream, then it returns the first
  /// [size] buffered elements.
  ///
  /// If end-of-stream is encountered before [size] elements is read, this
  /// returns a list with fewer than [size] elements (indicating end-of-stream).
  ///
  /// If the underlying stream throws, the stream is cancelled, the exception is
  /// propogated and further read operations will fail.
  ///
  /// Throws, if another read operation is on-going.
  Future<List<T>> readChunk(int size) async {
    final result = <T>[];
    // ignore: prefer_foreach
    await for (final chunk in readStream(size)) {
      result.addAll(chunk);
    }
    return result;
  }

  /// Read next [size] elements from _chunked stream_ as a sub-stream.
  ///
  /// This will pass-through _chunks_ from the underlying _chunked stream_ until
  /// [size] elements have been returned, or end-of-stream has been encountered.
  ///
  /// If end-of-stream is encountered before [size] elements is read, this
  /// returns a list with fewer than [size] elements (indicating end-of-stream).
  ///
  /// If the underlying stream throws, the stream is cancelled, the exception is
  /// propogated and further read operations will fail.
  ///
  /// If the sub-stream returned from [readStream] is cancelled the remaining
  /// unread elements up-to [size] are drained, allowing subsequent
  /// read-operations to proceed after cancellation.
  ///
  /// Throws, if another read-operation is on-going.
  Stream<List<T>> readStream(int size) {
    RangeError.checkNotNegative(size, 'size');
    if (_reading) {
      throw StateError('Concurrent read operations are not allowed!');
    } else {
      _reading = true;
      final substream = () async* {
        // While we have data to read
        while (size > 0) {
          // Read something into the buffer, if it's empty
          if (_buffer.isEmpty) {
            if (!(await _input.moveNext())) {
              // Don't attempt to read more data, as there is no more data.
              // ignore: parameter_assignments
              size = 0;
              _reading = false;
              break;
            }
            _buffer = _input.current;
          }
          if (_buffer.isNotEmpty) {
            if (size < _buffer.length) {
              final output = _buffer.sublist(0, size);
              _buffer = _buffer.sublist(size);
              // ignore: parameter_assignments
              size = 0;
              yield output;
              _reading = false;
              break;
            }
            final output = _buffer;
            // ignore: parameter_assignments
            size -= _buffer.length;
            _buffer = _emptyList;
            yield output;
          }
        }
      };
      final c = StreamController<List<T>>();
      c.onListen = () => c.addStream(substream()).whenComplete(c.close);
      c.onCancel = () async {
        while (size > 0) {
          if (_buffer.isEmpty) {
            if (!await _input.moveNext()) {
              // ignore: parameter_assignments
              size = 0; // no more data
              break;
            }
            _buffer = _input.current;
          }
          if (size < _buffer.length) {
            _buffer = _buffer.sublist(size);
            // ignore: parameter_assignments
            size = 0;
            break;
          }
          // ignore: parameter_assignments
          size -= _buffer.length;
          _buffer = _emptyList;
        }
        _reading = false;
      };
      return c.stream;
    }
  }

  /// Cancel the underlying _chunked stream_.
  ///
  /// If a future from [readChunk] or [readStream] is still pending then
  /// [cancel] behaves as if the underlying stream ended early. That is a future
  /// from [readChunk] may return a partial chunk smaller than the request size.
  ///
  /// It is always safe to call [cancel], even if the underlying stream was read
  /// to completion.
  ///
  /// It can be a good idea to call [cancel] in a `finally`-block when done
  /// using the [ChunkedStreamReader], this mitigates risk of leaking resources.
  Future<void> cancel() async => _input.cancel();
}

/// Extensions for using [ChunkedStreamReader] with byte-streams.
extension ChunkedStreamReaderByteStreamExt on ChunkedStreamReader<int> {
  /// Read bytes into a [Uint8List].
  ///
  /// This does the same as [readChunk], except it uses [collectBytes] to create
  /// a [Uint8List], which offers better performance.
  Future<Uint8List> readBytes(int size) async => collectBytes(readStream(size));
}

/// Collects an asynchronous sequence of byte lists into a single list of bytes.
///
/// If the [source] stream emits an error event,
/// the collection fails and the returned future completes with the same error.
///
/// If any of the input data are not valid bytes, they will be truncated to
/// an eight-bit unsigned value in the resulting list.
Future<Uint8List> collectBytes(Stream<List<int>> source) {
  return _collectBytes(source, (_, result) => result);
}

/// Generalization over [collectBytes].
///
/// Performs all the same operations, but the final result is created
/// by the [result] function, which has access to the stream subscription
/// so it can cancel the operation.
T _collectBytes<T>(Stream<List<int>> source, T Function(StreamSubscription<List<int>>, Future<Uint8List>) result) {
  final byteLists = <List<int>>[];
  var length = 0;
  final completer = Completer<Uint8List>.sync();
  // ignore: cancel_subscriptions
  final subscription = source.listen(
    (bytes) {
      byteLists.add(bytes);
      length += bytes.length;
    },
    onError: completer.completeError,
    onDone: () => completer.complete(_collect(length, byteLists)),
    cancelOnError: true,
  );
  return result(subscription, completer.future);
}

// Join a lists of bytes with a known total length into a single [Uint8List].
Uint8List _collect(int length, List<List<int>> byteLists) {
  final result = Uint8List(length);
  var i = 0;
  for (final byteList in byteLists) {
    final end = i + byteList.length;
    result.setRange(i, end, byteList);
    i = end;
  }
  return result;
}
