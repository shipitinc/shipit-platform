# Repository Learning: A port that shells out is a port that throws

**Feature**: IMPL-A2-CORRECTION-2 (implementation scheduler lane)
**Date**: 2026-10-13
**HEAD**: 67d2e1d (finding raised by `engineering-reviewer`, MEDIUM-1)
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.

---

## Summary

`ImplementationReadinessProbe.probe` documented itself as total: *"every path returns
either Ready or Deferred. It never throws."* One of its four injected ports was not
guarded, and that port's default implementation shells out. `Process.runSync` **throws**
when the process cannot start; it does not return a non-zero exit code. The contract was
false, and nothing between the throw and the scheduler's tick caught it.

**This entry deliberately restates almost nothing.** The executable form is in the
repository and cannot go stale:

| What is true | Where it is true, mechanically |
|---|---|
| What totality costs — all four ports, and how each fails | `apps/server/lib/src/implementation/implementation_readiness_probe.dart` — the table on `probe` |
| That `_gitRevParse` can throw, and why its caller must not move it out of the `try` | same file, on `_gitRevParse` |
| Each port failing individually | `implementation_readiness_probe_test.dart` — "no injected port can throw out of the probe" |
| The blast radius: one bad clone must cost one job, not the tick | same file — "one job's broken clone costs that job ALONE" |

---

## The finding

The escape path, as observed (not as reasoned — the stack trace is reproducible by
running the test at the pre-correction HEAD):

```
implementation_readiness_probe.dart:350   probe            <- _resolveCommit, unguarded
implementation_readiness_probe.dart:439   toWorkloadResolver.<fn>   <- awaits probe bare
scheduler.dart:765                        Scheduler._dispatchOne    <- awaits the resolver bare
scheduler.dart:660                        Scheduler.tick            <- the for(;;) dispatch loop
```

`_dispatchOne` is called once per eligible job inside a loop, so one product's
unreadable clone aborts the dispatch pass for **every other job in that tick**. No retry
is burned (the throw precedes the claim), the jobs stay queued, and the composition
root's per-section catch logs `implementation.tick.failed` — which is why it is a MEDIUM
and not a HIGH: nothing is stranded and it is observable. It was also unreachable today,
because nothing produces `implementationReady`. Unreachable is not the same as absent.

## Why the surrounding code made this invisible

`readProductState`, `readOnboarding` and `record.workspace!.requireDurable()` were all
wrapped in `try`. Three guards out of four read as "this method is total". The pattern
that hid it is that **the guards were written one at a time, at the point each port was
added**, so each was individually reasonable and nobody re-read the file asking "which
port is not in this list?"

The port that was missed is also the only one that is **not obviously fallible from its
type**: a reader sees `CommitResolver` returning a record with a nullable `commit`,
which *looks* like it already models failure. It does not model the case where the call
cannot be made at all.

## Why `Process` is worth a whole finding

`Process.runSync('git', …)` has two failure shapes, not one:

- git ran and refused → non-zero `exitCode` → the `(commit: null, output: …)` record the
  port was designed around.
- git could not be **started** → `ProcessException` is thrown → there is no `exitCode` to
  inspect, so every `exitCode`-based guard downstream is unreachable on this path.

The second is the one a reviewer has to know to look for, and it is not discoverable by
reading the port's happy path or its `record` type. `git` absent, `PATH` broken and fork
denied are all ordinary in a container.

## The correction, and the boundary deliberately not crossed

`probe` catches the throw and converts it to `(commit: null, output: '$error')`, which
lands on the existing `implementation.deferred.pin_unresolvable` deferral — deferred,
logged, no retry burned. The operator-facing `reason` distinguishes "git ran and said
this pin is not here" from "git never ran, so nothing is known either way", because
those send an operator to two different places and the first sentence of a deferral is
the only thing a human gets.

`Scheduler._dispatchOne` was **not** guarded. Two reasons, both load-bearing:

1. It is shared by triage, review, baseline and implementation. A guard there changes
   behaviour for every lane, not just this one.
2. Deciding that a throwing resolver becomes "defer, do not fail" is a choice about
   which channel a refusal travels on — and that channel is `OD-4`, an open product
   decision this lane is explicitly not answering. Silently answering it in a comment
   block would have been worse than leaving the gap visible.

The guard is at the port that actually shells out, which is also where the blast radius
is contained to this lane.

## The assertion that was missing, and the one that was really missing

The suite had no test for a throwing `readOnboarding`, and no test for a throwing
`resolveCommit`. Both are now present.

The instructive one is the pair the finding asked for, because **the first assertion
alone would have missed the actual defect**:

- (a) the probe returns a deferral rather than propagating — passes as soon as the
  `try` exists, and says nothing about the scheduler;
- (b) a *second, unrelated* job in the same tick still has its request built — this is
  the finding. It fails on the pre-correction HEAD and passes after.

(a) is a property of one method; (b) is a property of a chain. A totality contract is
about the chain.

The test asserts `attempted` contains *both* work item ids before asserting anything
about the healthy job. Without that, the test passes vacuously if the broken job is never
reached — and "the healthy job dispatched" then says nothing about whether a bad clone
can take the others down with it.

## Larger lesson — framework candidate, not persisted here

*Not persisted: `WORKFLOW_IMPROVEMENT` requires independent review.*

**When a method documents a totality or fail-closed contract, the guard is not finished
when the `try` is written.** Two requirements, both cheap:

1. **One test per injected port, raising that port's own failure.** A guard exercised by
   no test is one edit away from deletion, and "which ports did I guard?" is a question
   the file can answer only by reading all of it.
2. **For any port that shells out, the test's failure must be the one the runtime
   actually raises** — for `Process`, a throw, not an exit code.

And the structural point: **a fail-closed contract should be asserted at the layer the
failure reaches, not at the layer where it is caught.** Catching at the port is
necessary and not sufficient; the tick-level test is what proves the catch is in a place
that matters.