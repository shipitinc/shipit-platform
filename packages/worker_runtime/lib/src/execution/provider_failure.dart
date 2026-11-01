import 'package:platform_contracts/platform_contracts.dart';

/// Marker a worker stamps on `WorkerExecutionResult.failureDetail` — and on
/// the `WorkerExecution.reason` persisted beside it — when a timed-out agent
/// session died on the PROVIDER rather than on the work: the runtime produced
/// nothing at all, or its own diagnostic stream named a provider error.
///
/// ## WHY A MARKER AT ALL
///
/// Same defect class as [storeContentionMarker]: the classification crosses a
/// package boundary as a flattened string. `LocalWorker._drive` writes the
/// detail, `RetryPolicy.classify` in `packages/scheduler` copies it verbatim
/// into `JobFailure.reason`, and the scheduler's adoption path is the reader
/// that decides whether the retry escalates the model chain. The literal is
/// pinned HERE — the producer's package — and the consumer references the
/// same constant, so a rename breaks the build instead of silently reverting
/// to "no escalation".
///
/// ## WHAT IT MEANS, AND WHAT IT DELIBERATELY DOES NOT MEAN
///
/// It means "this execution never reached the work because something upstream
/// of it was dead" — the exact condition automatic model escalation exists
/// for. It does NOT mean "the agent's work was bad": a session that ran,
/// produced output and then failed carries no marker, because retrying a real
/// work failure on the paid tier is wasted money and the whole point of the
/// distinction.
const String providerFailureMarker = 'provider_unavailable:';

/// Whether [detail] — a `failureDetail` a worker execution reported, or a
/// `JobFailure.reason` that adopted it — carries [providerFailureMarker].
///
/// `contains` rather than `startsWith`: the honest timeout sentence leads
/// the detail ('agent session timed out; provider_unavailable: …'), matching
/// how the detail is read by operators. The marker itself is the contract —
/// surrounding prose is free to be reworded.
bool isProviderFailureDetail(String? detail) =>
    detail != null && detail.contains(providerFailureMarker);

/// The provider-dead signature, read off a persisted [AgentResult]: a short
/// evidence sentence when the result supports "the provider was
/// unavailable", or null when it does not.
///
/// Two honest signals, in order of strength:
///
///  * `metadata.providerError` — set by the agent session itself when the
///    runtime's stderr named a provider-side failure the ACP wire never
///    carried (quota exhaustion, rate limit, auth, unavailability). That is
///    POSITIVE identification: the runtime's own words, not an inference.
///  * ZERO ACTIVITY — the session produced no message chunks, ran no tool
///    calls and consumed no tokens before dying. A session that ran and hung
///    leaves nonzero counters, so this classifies "dead on arrival"
///    distinctly from "ran and stopped answering". An absence of output is
///    not proof of a provider outage in the strict sense — but it IS proof
///    the failure happened upstream of the work, which is the condition the
///    model chain exists to route around.
///
/// A null result is NO evidence: "cannot read the record" never escalates,
/// because the conservative direction is the one that does not spend the
/// paid tier on a guess.
String? providerFailureEvidence(AgentResult? result) {
  if (result == null) return null;
  final metadata = result.metadata;
  final providerError = metadata?['providerError'];
  if (providerError is Map) {
    final type = providerError['type'];
    // Only a CLASSIFIED provider error is positive evidence. The session
    // stamps `unknown` on every transport failure regardless of cause — an
    // error nobody could name is not a reason to spend the paid tier, so an
    // `unknown` entry falls through to the zero-activity check instead.
    if (type is String && type != 'unknown') {
      return 'the runtime reported a provider error ($type)';
    }
  }
  final usage = metadata?['usage'];
  final chunks = metadata?['chunkCount'];
  final used = usage is Map ? usage['used'] : null;
  final size = usage is Map ? usage['size'] : null;
  final cost = usage is Map ? usage['cost'] : null;
  final producedNothing =
      (chunks is num ? chunks : 0) <= 0 &&
      result.diagnostics.toolCalls <= 0 &&
      (used is num ? used : 0) <= 0 &&
      (size is num ? size : 0) <= 0 &&
      (cost is num ? cost : 0) <= 0;
  if (!producedNothing) return null;
  return 'the runtime emitted no output at all — 0 message chunks, 0 tool '
      'calls, 0 tokens — so the failure happened upstream of the work';
}
