# QA workspace retained until gate evaluation completes

- **decision_id:** `9b7e4c31`
- **decided:** 2026-10-21
- **decided_by:** human (via structured question UI)
- **supersedes:** the `cleanupPolicy: removeAlways` behaviour every QA `worker_execution` row carried
- **gate:** `product_qa_contract` gates F1 (`implementation-artifact-provenance`) and F5
  (`revision-identity-match`)

## Decision

QA workspaces are **retained until gate evaluation completes, then removed**.

## Why it was put to the human

Slice 3c wired the QA drain at `a7931a4`. With it running, the implementer measured that **F1 and F5 cannot
honestly pass against live QA data**: every QA execution row carried `cleanupPolicy: removeAlways`, so the
checkout each gate re-reads unconditionally was already gone by evaluation time. The lane reported this rather
than bypassing the re-read to force a pass — the correct call, because a gate that reads nothing cannot say
anything.

The result without this decision: feature items transition into QA and fail for a **infrastructure** reason,
not a quality one, which is a fail-closed outcome that carries no signal.

## Why not the alternatives considered

- **Record provenance instead of re-reading** — shifts what F1/F5 prove from *"I read git myself"* to *"I read
  a record somebody wrote"*, weakening the gate the design deliberately made an unconditional re-read.
- **Leave as-is** — the ten queued feature reviews never complete.

## Conditions attached

- The workspace is still removed **unconditionally** when the run finishes — on success, on failure and on
  interrupt alike. This decision changes *when* removal happens, never *whether* it happens. It is not a
  licence to leak resources; `docs/engineering/AGENTS.md` test-resource hygiene continues to bind.
- The re-reads themselves are **not** modified. F1 keeps reading HEAD unconditionally and F5 keeps re-reading
  the produced revision. This decision restores the data they read; it does not relax what they check.

## Status

Recorded. Implementation is dispatched separately and must be independently reviewed.
