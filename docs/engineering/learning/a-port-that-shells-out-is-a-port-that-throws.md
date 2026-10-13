# Repository Learning: A port that shells out is a port that throws

**Feature**: IMPL-A2-CORRECTION-2 and -3 (implementation scheduler lane)
**Date**: 2026-10-13
**HEAD**: 67d2e1d (finding raised by `engineering-reviewer`, MEDIUM-1); extended at
IMPL-A2-CORRECTION-3 after `focused-reviewer` rejected the first closure on the same
defect class.
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.

---

## Summary

`ImplementationReadinessProbe.probe` documented itself as total: *"every path returns
either Ready or Deferred. It never throws."* Some of its injected ports were not guarded,
and one of those ports' default implementation shells out. `Process.runSync` **throws**
when the process cannot start; it does not return a non-zero exit code. The contract was
false, and nothing between the throw and the scheduler's tick caught it.

The first fix guarded that port and then **stated the result with a wrong count** — it
claimed four ports and four guards while counting a method that is not a port and
omitting two that were, one of them unguarded. The second fix guards all five and makes
the enumeration true. Both halves of that story are the finding.

**This entry deliberately restates almost nothing.** The executable form is in the
repository and cannot go stale:

| What is true | Where it is true, mechanically |
|---|---|
| What totality costs — all FIVE injected ports, and how each fails | `apps/server/lib/src/implementation/implementation_readiness_probe.dart` — the table on `probe` |
| That `_gitRevParse` can throw, and why its caller must not move it out of the `try` | same file, on `_gitRevParse` |
| That `_directoryExists` can throw, and why `false` is not the only alternative | same file, on `_directoryExists` |
| Each port failing individually | `implementation_readiness_probe_test.dart` — "every injected port is guarded separately — none throws out" |
| The blast radius: one bad clone must cost one job, not the tick | same file — "one job's broken clone costs that job ALONE", and "an UNREADABLE clone costs that job ALONE" |

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
wrapped in `try`. Three guards in a row read as "this method is total". The pattern
that hid it is that **the guards were written one at a time, at the point each port was
added**, so each was individually reasonable and nobody re-read the file asking "which
port is not in this list?"

The port that was missed is also the only one that is **not obviously fallible from its
type**: a reader sees `CommitResolver` returning a record with a nullable `commit`,
which *looks* like it already models failure. It does not model the case where the call
cannot be made at all.

## The correction of the correction: the enumeration was wrong too

The first fix guarded `_resolveCommit` and then **stated** that totality now held —
in a table reading "there are four injected ports and each one is separately able to
fail, so totality here is four guards rather than one claim." A focused re-review
rejected it, and was right to. There are **five** injected function ports:

| | counted as a port | actually a port |
|---|---|---|
| `readProductState`, `readOnboarding` | yes | yes |
| `_resolveCommit` | yes | yes |
| `record.workspace!.requireDurable()` | **yes — it is not** | a method on a record a port already returned |
| `_repositoryExists` | **no — it was omitted** | yes, and it had **no guard at all** |
| `_log` | **no — it was omitted** | yes, and it had **no guard at all** |

So the table counted a non-port, omitted two real ports, and one of the two it omitted
was itself unguarded. The claim was not merely incomplete; the specific number was the
defect.

`_repositoryExists` is `Directory(path).existsSync()`, and on a path component that
denies traversal it **throws** `FileSystemException` (`OS Error: Permission denied,
errno = 13`) rather than answering `false`. Reproduced, not reasoned:

```
FileSystemException: Exists failed, path = '.../locked/repo' (OS Error: Permission denied, errno = 13)
dart:io                                                  _Directory.existsSync
implementation_readiness_probe.dart:518:55               _directoryExists
implementation_readiness_probe.dart:364:27               ImplementationReadinessProbe.probe
implementation_readiness_probe.dart:497:23               toWorkloadResolver.<fn>
scheduler.dart:765:11                                    Scheduler._dispatchOne
scheduler.dart:660:25                                    Scheduler.tick
```

Byte-for-byte the same escape as `_resolveCommit`, one row lower in the same table.

`_log` is unguarded too, and is worse: it is called from inside `catch` blocks, so a
throw from it escapes the very handler that was recording why the work was refused. The
default cannot throw; the composition root's `stdout.writeln` can, on a closed pipe.
It is now guarded at `_deferred`, the single choke point every deferral passes through.

### The durable lesson — and it is the one worth keeping

**A specific, checkable, WRONG enumeration is worse than an obviously-unverified
promise.** "It never throws" is vague enough that a reader suspects it. "There are four
ports and four guards" reads as *verified* — it has a number in it, and a number is
what makes a claim feel counted rather than asserted. The specificity is exactly what
invites trust, and it is what made a reader stop counting at four.

The corollary is that **a correction that adds a guard must re-derive its own
arithmetic.** The first fix added a `try` and simultaneously wrote a summary sentence
about the result, without asking whether the summary's count had just changed. Adding
a guard changes the number in the sentence describing the guards. Nobody re-read the
sentence because nobody thought the sentence was part of the code.

It also took a *second* finding to notice that a guard added by correction-1 was
recorded **in the very artifact written to record finding-1's closure** — which is why
it blocked rather than nitpicked. The artifact that closes a finding inherits the
finding's own blind spot unless it is re-opened and re-counted from the source.

## Why `Process` is worth a whole finding

`Process.runSync('git', …)` has two failure shapes, not one:

- git ran and refused → non-zero `exitCode` → the `(commit: null, output: …)` record the
  port was designed around.
- git could not be **started** → `ProcessException` is thrown → there is no `exitCode` to
  inspect, so every `exitCode`-based guard downstream is unreachable on this path.

The second is the one a reviewer has to know to look for, and it is not discoverable by
reading the port's happy path or its `record` type. `git` absent, `PATH` broken and fork
denied are all ordinary in a container.

**The same two-shape split appears in `Directory.existsSync`**, which is what made the
counting error so easy to miss: a reader who has just internalised "`Process` can throw"
generalises it to "shell-outs can throw" and stops there, because the filesystem port is
not a shell-out and was never on the list they were holding in mind.

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

## A boundary that was drawn too narrowly, and how it moved

The reasoning above ended with: *"the guard belongs at the port that actually shells
out."* That was applied narrowly — it kept `_repositoryExists` outside the guard,
because `_repositoryExists` does not shell out.

**That reasoning does not transfer to a port that touches the filesystem directly.**
`_resolveCommit` is guarded because a shell-out has a second failure shape. That is a
statement about *how ports fail*, not about *which ports are dangerous* — and
`Directory.existsSync()` has the same second shape, arrived at without a `Process` in
sight. What justified a guard was "this port can raise", and `_repositoryExists` could.
The shell-out was an example of the hazard, not the definition of it.

The narrower boundary was not wrong about `_dispatchOne`; it was wrong only because it
had generalised the hazard to a category ("ports that shell out") instead of to the
property that actually makes it dangerous ("ports that can raise").

## The assertion that was missing, and the one that was really missing

The suite had no test for a throwing `readOnboarding`, and no test for a throwing
`resolveCommit`. Both are now present — and the second correction round added the two
that the wrong enumeration had left untested, `repositoryExists` and `log`.

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
   actually raises** — for `Process`, a throw, not an exit code. **And the same applies
   to any port that touches the filesystem**: for `Directory.existsSync`, a throw, not
   `false`.
3. **Count the ports, and then make the count fail if it drifts.** The first fix wrote a
   confident "four ports, four guards" sentence in the same edit that added a guard. A
   tally written by the same hand that changes the thing being tallied is the one tally
   nobody re-checks. If the contract states a number, some test should be able to fail
   when the number stops matching — otherwise the number is decoration that happens to
   look like verification.

And the structural point: **a fail-closed contract should be asserted at the layer the
failure reaches, not at the layer where it is caught.** Catching at the port is
necessary and not sufficient; the tick-level test is what proves the catch is in a place
that matters.