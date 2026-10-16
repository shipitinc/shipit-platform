# The reviewer was never told what a verdict is

**Category:** `PROJECT_FACT` (verified, executable) · **Authority:** automatic
**Date:** 2026-10-15 · **Base:** `6ef8a1b` · **Lane:** `IMPL-B9-VERDICT-ABSENCE`

## The observation

Four work items sat at `review_in_progress` with `structuredResultJson = {}`, no decision,
and nothing on the operator's screen. Their reviews were not failures: they ran to
completion and produced genuine, specific findings against real commits — `18ad90a`,
+957/−199, a blocking finding that `_DesktopSkeletonRow` lays its trailing placeholders
out as `142/132/72` against column constants that do not line up.

`93587cf` (b1) had already made a decision unreachable without a real parsed verdict, and
that containment is why the symptom is silence rather than a fabricated
`CHANGES_REQUIRED`. That part was correct. What it exposed underneath was that **no
verdict had ever been produced**, so the containment had nothing to contain.

## The cause, traced to its source

The verdict is extracted from a JSON object in the agent's final assistant message. Three
facts, each verifiable, make a missing verdict a prompt defect rather than a runtime one:

1. **The review scheduler already has its own instruction builder.** The suspicion that
   the reviewer was being handed `Scheduler._defaultInstruction` — *"Implement …"* — is
   **wrong**. `apps/server/lib/server.dart:501` constructs the review scheduler with
   `instructionBuilder: engineeringReviewInstruction`.

2. **That instruction was the entire specification the reviewer got.** It read, in full:

   ```
   Review the implementation for "<title>" (<workItemId>).
   Provide independent assessment and return an engineering review verdict.
   ```

   No JSON, no key name, no wire tokens, no shape. `OpenCodeSession` opens its session
   with `{'cwd': ..., 'mcpServers': []}` — **no agent name, no system prompt, no role**
   (`opencode_session.dart:298`). A reviewer asked for "a verdict" in prose, with nothing
   else anywhere telling it otherwise, writes a review.

3. **The reader is strict and correct.** `_readReviewVerdict` reads
   `structuredResult['verdict']` into `ReviewVerdict.fromWire`, which throws on anything
   that is not an exact token. `CHANGES_REQUIRED`, `changesRequired`, `APPROVED` all fail.

So: reviewer writes prose → `_structuredPayload` correctly finds no JSON object →
`structuredResult == {}` → `structured['verdict'] == null` → `_NoVerdictCause.verdict_absent`
→ b1 records the absence and returns. Every link behaved as designed. The defect was
between them, in a two-line prompt.

## The contrast that makes it obvious

`triageDefectInstruction` — same package, same reader architecture — is a ~50-line payload
contract. It says *"output a STRUCTURED JSON result with exactly these fields"*, lists every
wire token, forbids prose outside the JSON, and is guarded by
`test/lane_m_triage_prompt_contract_test.dart`, which reads the documented values back out
of the generated string and asserts they equal the live enum tokens.

The triage lane parses. The engineering-review lane did not. **The difference between those
two outcomes is the prompt, and nothing else.**

## The fix, and why the prompt cannot be allowed to bias

`engineeringReviewInstruction` is now a payload contract rendered from the enums rather than
transcribed, so adding a `ReviewVerdict` member changes the prompt on the next build
instead of silently un-parsing reviewer output.

The prompt states what each of the four verdicts **means** and that the platform records
whichever one comes back. It names no token as a default, a fallback, or an expectation, and
it forbids misreporting in **both** directions — do not invent a problem you did not find, do
not soften one you did. A reviewer that genuinely found nothing is told that is a real result
with an honest answer among the four, and is told so **without naming a token**, because
naming one would make it appear more often than the others and that asymmetry is itself a
nudge.

`test/engineering_review_prompt_contract_test.dart` enforces all of this as executable
knowledge: the documented tokens must equal `ReviewVerdict.values.map((v) => v.wire)`, every
documented token must actually parse, no caps or camelCase may appear, and a group of
ANTI-BIAS tests asserts no token is named as a default/fallback/expectation and that all
four appear the **same number of times**. Restoring the original two-line instruction makes
8 of them red.

### The generalisable rule

> **A prompt that names only the conclusion, while a strict parser reads a specific
> structure, produces silence — and the fix is never to loosen the parser.**
>
> Before writing a prompt that a strict reader consumes, ask what that reader's first
> lookup is, and make the prompt name it literally. Before writing a prompt that demands a
> classification, ask which way it leans when the model is unsure, and forbid leaning.

## Truncation was investigated and is NOT implicated

`summary` is truncated at 2000 characters, and every QA row showed exactly 2000 — a
suspicious coincidence. It is a red herring:

- `OpenCodeSession.getResult` calls `_structuredPayload` on the **full** `_finalText()`
  and only afterwards truncates when building `summary`.
- Extraction therefore sees every character. The truncation bounds what a *human* reads,
  not what the *platform* reads.

Proven executably by `packages/agent_runtime/test/opencode_summary_truncation_test.dart`:
a verdict placed beyond byte 2000 is still extracted into `structuredResult`, while the same
message's `summary` is exactly 2000 characters and provably does **not** contain the
verdict. The inverse is asserted too — a long message with no JSON still yields an honest
empty payload, so length can never conjure a verdict.

## A second, quieter loss found on the way

`DesignFinding` requires eleven fields. Five of them — `findingId`, `revisionId`,
`reviewExecutionId`, `createdAt`, `version` — are run identity a reviewer **cannot** supply
(it does not know its own `reviewExecutionId`), and one, `category`, is a design-review
taxonomy an engineering reviewer has no honest choice among.

So a reviewer could not answer the documented question without inventing provenance, and any
finding it did emit was dropped as unparseable by a `try`/`catch` that logged and moved on.
`_readReviewVerdict` now stamps exactly those six from the run it is already holding —
`reviewExecutionId` from the execution, `revisionId` from the reviewer's own
`workspace.startingRevision` (the commit actually under review), `createdAt` from the result,
and `category` as `feasibility`, matching b1's own engineering-review fixtures. **Every
value is read, not guessed, and only ABSENT keys are filled.** A finding that arrives with
its own identity keeps it.

## Verification

- `packages/scheduler/test/engineering_review_prompt_contract_test.dart` — 14 tests. **8 red**
  against the original instruction, green against the fix.
- `apps/server/test/engineering_review_verdict_end_to_end_test.dart` — 7 tests driving the
  **real** `OpenCodeSession` extractor and the **real** gate. Red at base in two independent
  ways: on the old prompt (no contract) and on the old finding reader (evidence dropped).
- `packages/agent_runtime/test/opencode_summary_truncation_test.dart` — 3 tests.
- b1's three named fabrication sites re-run individually and green.

## Related

- `a-wire-that-went-quiet-is-not-a-verdict.md` — the same principle on the transport side.
- `no-verdict-is-not-no-review.md` — b1's containment, which this un-blocks by supplying the
  verdict it was correctly refusing to invent.