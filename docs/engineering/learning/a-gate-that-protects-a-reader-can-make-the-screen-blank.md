# A gate that protects a reader can also make the reader's screen blank

**Category:** `PROJECT_FACT` (verified, executable) · **Authority:** automatic
**Date:** 2026-10-15 · **Base:** `2b29bdd` · **Lane:** `IMPL-B9-Q2-VERDICT-LESS-DECISION`
**Decision:** `c495e02f-5c5d-4b45-8124-42ad0e90d6d4` (ARCHITECTURE, RESOLVED, option A)

## The observation

`93587cf` (b1) removed three `changesRequired` fallbacks from the engineering-review gate and
asserted, in three named tests, that a reviewer which produced no verdict raises **zero**
`HumanDecision` rows. That work was correct: three items were showing *"Engineering review
requires changes"* for code nobody had assessed, and a fabricated verdict is the worst thing
this platform can do.

It also, four reviews later, produced silence. Four reviewers reached `completed` against real
commits and wrote real findings in prose. All four recorded `{}` in `structuredResultJson`. No
verdict was parsed, so no decision was raised, so all four items sat at `review_in_progress`
with nothing on any operator screen — and nothing was coming, because the job **succeeded**,
and `maxAttempts` only ever retries a failure. The containment was working. It contained
everything, including the fact that a review had happened.

## The distinction that decides it

Two invariants read alike and are not the same:

* **"no decision exists without a parsed verdict"** — what b1 asserted.
* **"no decision asserts a verdict that was not parsed"** — what actually protects a reader.

The first forbids a decision that says *no verdict was produced*. The second permits it, and
that decision preserves the first's whole purpose: it claims nothing about the work. Decision
`c495e02f` ruled for the second, and the gate now raises one such decision when — and only
when — the reviewer execution reached `completed`, which is the only state in which nothing
else will move the item.

## What the amended assertions had to keep saying

The ruling required the three zero-row assertions be **amended, not deleted**, because a
weakened test with no context invites a future reader to restore the original believing it was
the safety property. Two of them had to change (a completed review with `{}`, and a completed
review with an unrecognised wire) and one did not (a timed-out reviewer still raises nothing,
because `maxAttempts` is still owed to it and `Scheduler._returnOneToEntryState` skips
`waitingForHumanDecision`).

The property that had to survive both amendments is the sharp one: an **unparsed** wire is
still `verdict_unreadable`, still no verdict, and still refused. A zero-row assertion could be
satisfied by a decision that is merely *quiet* about the verdict — and quietness is exactly the
failure being fixed — so the amended assertions name every field a verdict could be read from
(`reviewVerdict`, `engineeringReviewResult`, the recommendation rendered under "WHAT WE
SUGGEST") and require each to be free of one. That is stricter about the property the test was
written for than the count it replaced.

Executable:

```
dart test apps/server/test/engineering_review_never_fabricates_verdict_test.dart
dart test apps/server/test/engineering_review_verdict_end_to_end_test.dart
dart test apps/server/test/engineering_review_verdict_absent_decision_test.dart
dart test apps/server/test/engineering_review_verdict_absent_smoke_test.dart   # red at 2b29bdd
```

## Three things the shape of the fix forced into the open

**The reviewer's prose is not optional.** All four reviews did real work. A decision saying
"nothing happened" would have replaced one false state with another, so the decision carries the
reviewer's own `summary` verbatim and labels it as prose that has *not* been read as a verdict.
This also makes the two existing recovery paths fall out correctly:
`readReviewVerdictProvenance` classifies it `reviewerProseOnly`, which is deliberately NOT
repairable, so `repairUnreviewedReview` tells the operator to read the review and resolve the
decision rather than offering a button that discards a real assessment. With no prose it is
`noReviewerOutput` and the "set aside and re-review" affordance is available instead.

**"Not offered" is a property of the screen, not of the record.** `WorkflowEndpoints.
resolveDecision` takes a `choice` off the wire and hands it to `HumanDecisionChoice.fromWire`
without ever checking it against the decision's own `options`. A verdict-less decision offering
only `rework` and `cancel` is therefore not enough on its own, so
`ControlPlaneService.resolveHumanDecision` refuses `approve` and `reject` on exactly this
decision type. Scoped on purpose: "every choice must be one of the decision's options" would
change every lifecycle gate in the platform and is not what the decision asked for.

**Two gates, one decision type.** A supersession stall (b8) also stops a work item from moving,
and it also raises `engineeringReview` — because `reviewInProgress -> waitingForHumanDecision`
carries `blockingHumanDecisionPendingOfType([engineeringReview])` and admits no other type from
that state. `DecisionView` carries `question`, `recommendation` and `options` and **no metadata
field**, so the two must differ on all three or no screen in this repository can tell them
apart. They do: distinct metadata keys (`reviewVerdictAbsent` vs `schedulerStall`), a
recommendation that opens with the literal words `NO VERDICT` rather than the stall's `REWORK`,
different opening sentences, and option labels that share no word.

## Larger lesson — framework candidate, NOT persisted here

*Not persisted: `WORKFLOW_IMPROVEMENT` requires independent review.*

**An invariant that prevents a record from lying should be written as "no record claims X", not
as "no record exists without X".** The first survives the arrival of a legitimate, useful record
that says nothing; the second forbids it, and the cost of that forbidding is paid invisibly,
where no dashboard looks — in an operator's empty queue. The tell is a test that asserts a row
**count** where the property is about row **content**: a count cannot distinguish "this says
nothing" from "this says nothing on purpose", and it will silently accept the first while
quietly forbidding the second.