# Dispatch — review-acp-permission-responder

```yaml
MANAGER: orchestrator-main
TASK_ID: review-acp-permission-responder
TASK_TYPE: review
FEATURE: ACP transport answers session/request_permission (F-244 — auto-deny, turn continues)
AREA: agent_runtime ACP layer
WORKTREE: /private/tmp/shipit-fix-acp-perm
BRANCH: fix/acp-permission-responder
BASE_SHA: 2e56eee
HEAD_SHA_UNDER_REVIEW: 9848ed139ff751a389e2f211e232e13053fcf05b
ROUTING_CLASS: PRECISION
```

Independent read-only review of `9848ed1` — the transport now routes id+method server→client
frames to a `_onServerRequest` responder BEFORE the `_pending` completer lookup:
session/request_permission → deny via the offered reject-kind optionId (fallback `cancelled`);
every other server method → -32601; writes guarded by isOpen/try-catch on a dead pipe.
Denied asks recorded as a `permission_requests_denied` warning diagnostic on the result.

Verify rigorously:
1. The defect mechanism claim — the implementer asserts the wire contract from opencode 1.18.33
   bundled source: a server→client REQUEST carries id+method; the outcome parser maps any
   non-allow selection / cancelled / wire error to one-shot deny; only external_directory +
   doom_loop ask by default. Verify this matches the actual wire/transport behavior — don't
   take the claim on faith; check the request routing (id+method → _onServerRequest before
   _pending) actually delivers the response opencode waits on.
2. The DENY policy correctness — auto-deny on every ask: verify it's genuinely one-shot deny
   (no persisted rule), returns an ordinary tool error so the turn CONTINUES, and never selects
   once/always. The alternative (auto-grant) is rejected correctly — external_directory is
   arbitrary host-path access on an UNSANDBOXED child holding worker credentials.
3. The latent id-collision fix — a server request id colliding with a pending client request
   id previously completed the wrong completer; verify id+method routing happens before the
   _pending lookup so a colliding server request can't wrongly complete a client request.
4. Unanswerable surface closed — every server→client request gets a response (permission→deny,
   other→-32601); a dead-pipe write is guarded; a request can never hang the turn again.
5. Tests non-vacuous — the loopback tests hold a turn on an unanswered permission ask (id
   colliding with the pending prompt), assert deny + signal + turn-completion, and -32601 for
   an unimplemented method; the diagnostic test counts denied asks.
6. Gates re-run: `dart format --set-exit-if-changed .` (root — NOTE the implementer's discovery:
   on a fresh worktree `dart pub get` must precede format or it reports phantom changes);
   `dart analyze` + `dart test` (agent_runtime, worker_runtime, execution_coordinator) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.
