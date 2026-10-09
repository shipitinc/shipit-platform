import 'dart:typed_data';

/// Private key material that cannot be printed, interpolated or serialised by
/// accident.
///
/// ADR 0018 §A2 is the governing clause and it is load-bearing:
///
/// > The private half is never displayed, logged, persisted to the durable
/// > record, or transmitted, exactly as the surviving clause above requires.
///
/// A bare `Uint8List` defeats that clause by omission rather than by decision.
/// Every leak below is one line of innocent-looking code, and none of them
/// looks like a security decision to a reviewer:
///
/// ```dart
/// logger.error('store.failed', {'error': '$e'});       // e.toString() has it
/// throw StateError('bad seed ${base64.encode(seed)}');  // an "helpful" message
/// expect(seen, contains(secret));                        // a failing assertion
/// ```
///
/// The first two put key bytes in a log line — and this repository's structured
/// logger writes to the Serverpod session log, which is itself **persisted to
/// Postgres**, so "logged" and "persisted to the durable record" are the same
/// sink here. The third is the one the dispatch calls out specifically: *a test
/// that fails while including key material is itself a defect*, and a failing
/// test prints whatever the matcher was handed.
///
/// Wrapping the bytes makes leakage a compile-time impossibility instead of a
/// review-time catch: [toString] is the only textual projection and it emits a
/// length, never a byte. There is deliberately no `operator +`, no `toJson`, no
/// `List<int>` accessor — reaching the bytes requires an explicit, greppable
/// [bytes] call at the exact sites that genuinely need them (the cipher codec,
/// the identity-file writer, the secret-manager request body).
class SecretBytes {
  /// Wraps [value], copying it so a caller cannot mutate the secret through the
  /// original buffer afterwards.
  SecretBytes(List<int> value) : _bytes = Uint8List.fromList(value);

  final Uint8List _bytes;

  /// The raw bytes.
  ///
  /// Named for what it is and nothing else. Every call site is a place where
  /// private key material genuinely has to exist — ciphertext is computed from
  /// it, it is written to an owner-only identity file, it is base64'd into a
  /// secret-manager request body. There is no reason for it to appear anywhere
  /// else, and a repository-wide search for `.bytes` is the audit that proves
  /// there is no such place.
  Uint8List get bytes => _bytes;

  /// Length in bytes. Safe to log: it says how much there is, not what it is.
  int get length => _bytes.length;

  /// Overwrites the buffer with zeroes.
  ///
  /// Best effort, and deliberately documented as such. Dart cannot promise the
  /// original allocation is unreferenced — a `git` argv, an HTTP request body or
  /// a `String` built from these bytes may still hold a copy — so this narrows
  /// the window rather than closing it. It is called on every unwind path of
  /// the credential key service regardless, because "narrower" is still better
  /// than "never attempted", and the guarantee that matters is the one ADR 0018
  /// states: the material does not outlive the call.
  void wipe() {
    _bytes.fillRange(0, _bytes.length, 0);
  }

  /// Deliberately uninformative.
  ///
  /// Byte length only. Never the content, never a prefix, never an encoding —
  /// a prefix is still half a key.
  @override
  String toString() => '<secret redacted, ${_bytes.length} bytes>';
}
