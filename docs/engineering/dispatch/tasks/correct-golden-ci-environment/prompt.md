# Dispatch — correct-golden-ci-environment

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: correct-golden-ci-environment
TASK_TYPE: correct
FEATURE: Pin the golden gate to its rendering environment and make that environment a checked precondition
AREA: apps/control_plane/test/tools/** + .github/workflows/** on branch fix/golden-domination-n2
WORKTREE: /private/tmp/shipit-fix-golden-domination
BRANCH: fix/golden-domination-n2
BASE_SHA: f68a27ae561b9b06863f9b616878e9789026c533
OWNED_PATHS:
  - apps/control_plane/test/tools/**
  - apps/control_plane/test/helpers/**
  - .github/workflows/**
  - docs/engineering/dispatch/tasks/correct-golden-ci-environment/**
READ_ONLY_PATHS:
  - apps/control_plane/test/goldens/**
  - docs/engineering/dispatch/tasks/review-fix-golden-domination-n2/report.md
  - docs/engineering/dispatch/tasks/fix-golden-domination-n2/report.md
  - .decisions/3e9dfb75-7bdf-4a8c-89dd-c76779a65371.yaml
PROHIBITED_PATHS:
  - apps/control_plane/lib/**
  - apps/control_plane/test/goldens/**
  - apps/control_plane/test/**.dart
  - apps/server/**
  - packages/**
  - docker/**
  - docs/adr/**
  - .decisions/**
  - .agents/**
  - .claude/**
  - .junie/**
  - .opencode/**
ACCEPTANCE_CRITERIA: >
  The CI job is pinned to the environment that rendered the baselines (macOS arm64,
  Flutter 3.44.7), and the check REFUSES TO GRADE on any environment it cannot attest to,
  rather than grading. The noise-floor tests can fail. The false persistence claim is
  corrected. golden_tolerance.dart is unchanged.
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - cd apps/control_plane && flutter analyze
  - cd apps/control_plane && flutter test
ROUTING_CLASS: STANDARD
```

---

## Authority

Human Decision `3e9dfb75-7bdf-4a8c-89dd-c76779a65371`, **RESOLVED / OPTION_C — "Pin CI to the exact
rendering environment"**, via the structured question UI on 2026-10-08. Read it; it carries scope
discipline you must follow.

You are **continuing in the same worktree and branch** as the lane that produced `f68a27a`. Add new
commits on top. That lane is finished; you are the only writer.

## What independent review found — `DO_NOT_MERGE`, `HUMAN_DECISION_REQUIRED: YES`

Read `review-fix-golden-domination-n2/report.md` in full first.

**What is already verified and must NOT be disturbed.** The 40 regenerated baselines are correct.
The reviewer graded the whole corpus against fresh renders (`40 TOLERANCE-DOMINATED / 14 CURRENT`) and
confirmed all 40 are byte-identical to a fresh render of current source, verified twice independently.
`golden_tolerance.dart` is unchanged (blob `7cd735ca`, threshold `0.005` at line 43, single commit in its
entire history). No pre-existing test file was modified; `+190 → +207` closes at exactly +17. The
comparator still calls `GoldenFileComparator.compareLists`, and the new check grades a snapshot without
writing to baselines.

**The blocker is the CI wiring only.** Three environment axes are unmatched:

| | baselines | proposed job |
|---|---|---|
| OS | macOS 26.6.2 | macOS 14 |
| arch | arm64 | as provided |
| Flutter | 3.44.7 | 3.44.0 |

and the runner image is one `actions/runner-images` marks deprecated.

## The finding that matters most

**It is not a red job that is dangerous. It is a confidently wrong one.**

The check's noise-floor guard renders twice and compares those two renders **against each other**. On a
mismatched platform those two renders agree with each other, so the guard passes — and the check then
emits verdicts describing the **runner**, not the baselines. That is precisely the false assurance the
check was built to eliminate: it converts an unknown into a confident wrong answer.

## Required corrections

1. **Pin the job to the rendering environment** — macOS arm64, Flutter 3.44.7. Note the repo's `.fvmrc`
   pins 3.44.0; the baselines were rendered with 3.44.7. Resolve this deliberately and explain your
   choice — do **not** silently change the repo-wide SDK pin, which would affect every other package.
   Scope your change to this job.

2. **Make the environment a checked precondition.** The check must verify it is running where the
   baselines were rendered **before it grades anything**, and **refuse to grade** with a clear message
   otherwise. This is the core of the decision. If 3.44.7 turns out to be unavailable on the runner, the
   correct outcome is a job that refuses to grade — **not** a relaxed threshold and **not** a red build.
   Report which of those you achieved.

3. **Rewrite the noise-floor tests.** The reviewer found they compare a directory with itself and can
   never fail, so they attest to nothing. Executable knowledge that proves nothing is the same failure
   class this work item exists to remove. Write tests that **can** fail.

4. **Correct the persistence claim and the provenance.** The implementer claimed the finding was
   persisted as executable knowledge; that is false. Fix the claim, and fix report provenance that names
   dead pre-rebase SHAs (`c4fa46e`, `c68016a`).

## Absolute prohibitions

- **`golden_tolerance.dart` must not change** — not the threshold, not the comparator, not a bypass. It
  is the comparator's job to compare; your precondition is a separate layer that decides whether
  comparison is meaningful here.
- **The 40 regenerated baselines must not change.** They are verified correct; `apps/control_plane/test/goldens/**`
  is PROHIBITED to you. If you believe a baseline is wrong, report it — do not edit it.
- **No production source change.** `apps/control_plane/lib/**` is PROHIBITED.
- **No pre-existing test `.dart` file may be weakened, skipped, `@Ignore`d, filtered, or deleted.**
- **ZERO Docker/Compose commands** of any kind, including read-only-looking ones. This repository has
  already lost its QA database irrecoverably to a lane running `down -v`; the QA stack is up and healthy.
- `make test-integration`: **NOT required.** You need no database.
- Do not touch `.decisions/**` — you report the claim correction, the Manager persists it.

## Gates — verbatim output

Run `dart pub get` at the **REPO ROOT** first if `.dart_tool/` is missing.

| Gate | Command | Expected |
|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | `(0 changed)` — file count is whatever you added; the assertion is zero changes |
| analyze | `cd apps/control_plane && flutter analyze` | `No issues found!` |
| tests | `cd apps/control_plane && flutter test` | all pass |

## Proof required — the check must be observed failing, twice

1. **Precondition refuses.** Demonstrate the check refusing to grade when the environment does not match
   what the baselines were rendered on. Simulate the mismatch; show the refusal and its message.
2. **New noise-floor tests fail.** Demonstrate at least one of your rewritten tests failing on
   deliberately broken input, then passing when fixed. A test you have never seen fail is not a test.
3. **Happy path intact.** With the correct environment, grading proceeds and reports 54/54.

## Other lanes

- `design-qa-generator-migration` will hold `apps/server/migrations/**` + migration tooling design. You
  own `apps/control_plane/test/**` and `.github/workflows/**`. **No path overlap.**
- Manager holds `LANES.md` / `WORK_STATE.md` / `.decisions/**`.

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.

## Cleanup

Commit in logical commits. **Do not push, do not merge, do not touch `main`.** Start no container or
database — nothing to tear down.

## You cannot approve this

Report `READY_FOR_FOCUSED_REVIEW: YES` with recommended next action `FOCUSED_RE_REVIEW`. A fresh
independent `focused-reviewer` will verify you, targeting **only** these corrections plus regression risk.