import 'dart:io';

/// The contract an exception must satisfy before its text may reach a durable
/// record.
///
/// ADR 0018 §A2 forbids the private half from being "displayed, logged,
/// persisted to the durable record, or transmitted". [SecretBytes] discharges
/// that for **values this code holds**. It cannot discharge it for a value a
/// *third party* captured on our behalf — and a `dart:convert` `FormatException`
/// is exactly that: its message embeds an excerpt of the input it failed to
/// parse, which for `base64.decode` is base64 private-key material.
///
/// So this file is the other half of the guarantee, and it works at the level of
/// **types** rather than of call sites:
///
///   * an exception that has not declared itself [AuditedFailure] has its
///     message **suppressed**. It does not reach a log field, a session-log row,
///     or a rethrown exception. Only its `runtimeType` — a code identifier that
///     cannot contain bytes — is recorded.
///   * an exception that *has* declared itself provides [secretlessDescription],
///     which by contract is composed only from the fields that implementation
///     names. Every audited type in this directory does exactly that.
///
/// The consequence is that adding a new failing path cannot silently leak: a
/// new exception type is unaudited by default, so it is suppressed rather than
/// logged, and the failure it reports is still visible by name.
abstract interface class AuditedFailure {
  /// Text that is safe to write to a log line, a session-log row, or a durable
  /// column.
  ///
  /// MUST be composed from this implementation's own closed set of fields. It
  /// MUST NOT interpolate `toString()` of a caught error, and MUST NOT touch
  /// bytes. `test/secretless_error_test.dart` holds a guard test that reads the
  /// adapter sources and fails if a `SecretStoreException` `reason:` argument
  /// names a caught binding other than inside `secretlessText(...)`, and a
  /// second that drives the real local adapter and feeds real material-bearing
  /// failures through this function.
  String get secretlessDescription;
}

/// Renders [error] as text that may be persisted.
///
/// [error]'s own `toString()` is **never** called. An [AuditedFailure] supplies
/// its own description; a `dart:io` filesystem or subprocess failure is reduced
/// to the fields that class documents (an OS message and a path — it has no
/// field for file *content*, and this projection does not read `arguments`,
/// which is the only field of `ProcessException` that could carry one); anything
/// else is reported by type alone.
///
/// That is the structural half of the B-1 correction: no exception message can
/// reach a durable record unless its type opted in to being audited.
String secretlessText(Object error) {
  if (error is AuditedFailure) return error.secretlessDescription;
  if (error is FileSystemException) {
    final os = error.osError;
    final osError = os == null ? '' : ' (${os.message})';
    return 'FileSystemException: ${error.message}$osError'
        '${error.path == null ? '' : ' at ${error.path}'}';
  }
  if (error is ProcessException) {
    // `arguments` is deliberately NOT projected. Every subprocess this subsystem
    // spawns takes paths, modes and an `ssh://` URL — never key material — but
    // that is a property of the call sites, not of the class, so the field is
    // simply not read here.
    return 'ProcessException: ${error.executable}: ${error.message}';
  }
  return '<suppressed: ${error.runtimeType} is not an audited failure, so its '
      'message is not written to any durable record>';
}

/// Returns [error] itself when it is [AuditedFailure], and otherwise a
/// [UnauditedFailure] standing in for it.
///
/// Used at the endpoint boundary so the exception Serverpod logs for an
/// unhandled failure is one whose message is safe by construction. Rethrowing
/// the original would hand Serverpod — and therefore the persisted session log —
/// whatever message it carried.
Object redactUnauditedFailure(Object error) =>
    error is AuditedFailure ? error : UnauditedFailure(error.runtimeType);

/// Stands in for a failure whose type was never audited.
///
/// Carries the runtime type and nothing else. The original error and its stack
/// are not retained: an [AuditedFailure] conversion happens at the boundary
/// precisely so nothing downstream can reach back into the original message.
class UnauditedFailure implements Exception {
  UnauditedFailure(this.originalType);

  /// `error.runtimeType` of the failure this stands in for.
  final Type originalType;

  @override
  String toString() =>
      'UnauditedFailure: the original failure was a $originalType, which has '
      'not declared itself audited, so its message was suppressed rather than '
      'written to a durable record. Its type is recorded so the failure is '
      'still diagnosable.';
}

/// The clause every decode/parse refusal in this directory ends its sentence
/// with.
///
/// One constant rather than a phrasing repeated at each site, so the policy is
/// greppable and a site that forgets it is obvious in review. It is a `const`
/// with no interpolation, which is what makes it safe to reach a durable record
/// at all.
const String kNoMaterialEchoed =
    'the offending bytes are deliberately not echoed, because a decoder '
    'exception message would carry them';
