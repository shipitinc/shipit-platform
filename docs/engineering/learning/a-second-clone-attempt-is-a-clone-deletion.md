# Repository Learning: a second clone attempt was a clone deletion

**Feature**: IMPL-A3-WORKSPACE-PROVISIONING (operator-triggered durable workspace provisioning)
**Date**: 2026-10-13 · rewritten 2026-10-13 after `e82a120` (IMPL-A1B-MATERIALIZER-ORIGIN) merged
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.

> **This file was wrong on 2026-10-13 and says so above its own title.** It read *a second
> clone attempt **is** a clone deletion* and asserted, as a fact about the current tree,
> that `SshDurableWorkspaceMaterializer.materialize()` had **no idempotence guard of its
> own**. A parallel lane added one while this file was being reviewed. The hazard chain
> below is still the reason the guards exist and is unchanged; the claim about what the
> code does about it was false at the next HEAD, and no gate turns red when a claim like
> that goes stale. The title is in the past tense now because that is the only tense the
> tree supports.

---

## Summary: there are TWO guards, at different layers, each covering a case the other cannot see

| | **Guard A — the materialiser** | **Guard B — the trigger** |
|---|---|---|
| Lives in | `SshDurableWorkspaceMaterializer.materialize()` (`apps/server/lib/src/baseline/durable_workspace_materializer.dart`) | `DurableWorkspaceProvisionTrigger.provision` guard #5 (`apps/server/lib/src/services/control_plane_service.dart`) |
| Decides from | the **filesystem**: `rootPreExisted = root.existsSync()`, read before the `try`, before any byte is written | the **record**: `store.readOnboardingForProduct(productId)` and `existing.hasDurableProductClone` |
| Answers | "did **this call** create that directory?" | "does this product already have a recorded durable clone?" |
| On a second attempt | throws `DurableWorkspaceRootCollisionException` **before writing a byte**, and the `on Object` handler destroys the root only `if (createdRoot && …)` — so it preserves it | throws `DurableWorkspaceProvisionRefused(alreadyProvisioned)` **before asking A1 for anything**: no credential read, no host-key scan, no clone, no record rewrite |
| Property it owns | **no caller, from anywhere, can turn an existing tree into a delete** — *subject to the single-writer precondition in the RESIDUAL section below, which this property does not satisfy on its own* | **this product's clone is never replaced, and the refusal costs nothing** |

They are **defence in depth, not a chain and not a fallback.** Two claims about them, and
they are different claims — a previous version of this file ran them together, which is how
a learning file ends up asserting a measurement nobody made:

**(1) Across layers.** Each layer's guard covers a case the other cannot see, and neither
is redundant:

- Take away **B** (the trigger's) and a second run reaches the materialiser, which then
  refuses it (A). The clone survives — but a credential has been acquired, a host key
  matched, and the operator is told about a *collision* rather than about the thing they
  actually asked for.
- Take away **A** (the materialiser's) and B still holds on the production path, because
  no second attempt ever starts. But a **direct** call to `materialize()` / `provision()`
  and the **orphan tree** (below) would then destroy. A's guards are the ones that hold
  the filesystem property for *every* caller; B's is the one that holds it cheaply.

**(2) Within the materialiser, A1B measured that TWO of its own guards are
independently load-bearing** — removing either alone still deletes the tree:

- Remove the **entry refusal** (`rootPreExisted`) and the run reaches `remote add`,
  exits 3, destroys.
- Remove only the **`createdRoot &&` condition on the destroy**, entry refusal intact,
  and the refusal *itself* throws inside the `try`, is caught by `on Object`, and
  destroys. **Refusing became the deletion.**

The second is the one worth remembering. A guard that throws from inside the try block is
still flowing through the very cleanup path it was meant to constrain, so the cleanup has
to be conditioned on ownership too. **A guard is not a substitute for making the
destructive path provenance-aware. They are the same requirement expressed twice.**

It would be wrong to generalise (2) to the cross-layer pair: it is *not* true that
removing either of the two layers above leaves the clone deletable by any path, because
A's entry refusal alone already refuses a direct call. What is load-bearing is the pair
of cases, not a shared indispensability.

### Which layer owns which property — said precisely

**A owns the filesystem property.** It holds for *every* caller: the trigger, the
runtime, a future lane, a test. Nothing has to be remembered to get it. It also covers
the case **B structurally cannot see**: `provision()` materialises at
`durable_workspace_runtime.dart:485` and writes the onboarding record at `:500+`, so a
record write that fails after a successful clone leaves an **orphan tree**. The next
instruction finds no record, guard B says "not provisioned", and the old code deleted
that tree on its way to the same error. A refuses that tree because it did not create it,
and names what it found in it.

**B owns the cost and the diagnosis property.** A's refusal happens *after* the runtime
has read the active credential, scanned and matched the confirmed host key, and handed
the private half into the materialiser. B's refusal happens before any of that. So a
refused re-provision through the trigger is free and is reported as *"already provisioned
at `<sha>`"* (`control_plane_service.dart:2425`), with the operator told that
`$_provisionDurableWorkspaceEnv` *"MAY NOW BE CLEARED from the deployment environment"*
(`server.dart:1985`); the same attempt as a direct `materialize()` is a credential
acquisition that ends in a collision exception.

## The hazard chain — why any of this exists (unchanged, and still true of `git`)

This part was never falsified and is still the mechanical reason both guards are here:

1. A second run materialises into the SAME `$workspaceRoot/$productId` tree, because the
   product root is derived from the product id and nothing else.
2. `git init` against an existing repository succeeds — it is idempotent.
3. `git remote add origin <url>` then **fails**, because `origin` is already there. Exit
   code 3, `error: remote origin already exists`.
4. Before `e82a120`, the materialiser treated any non-zero git exit as a failed
   provisioning, and its `on Object` handler destroyed the whole product root — the
   existing clone, its `.git` object store, and every unreviewed commit in it.

Step 4 is what changed. Steps 1–3 are properties of `git` and still hold. So "just run it
again" is no longer the destructive verb — but it is still the wrong verb, and the reason
is now cost and error quality rather than data loss. A direct call re-runs the whole
credential and host-key chain to arrive at a collision error an operator will read as a
broken machine rather than as "you already have this".

## `DurableWorkspaceRuntime.provision()` still has NO guard of its own — this half is unchanged

The runtime reads the credential, verifies access, and calls
`materializer.materialize(productRoot: '$workspaceRoot/$productId')`. It **never reads
the onboarding record**. So called directly a second time it will still materialise
again, and `engine.recordWorkspace` will still **rewrite the one onboarding row and bump
its version**, leaving no trace that a second attempt happened.

That is the half of the attribution that survives `e82a120`, and it is why guard B is not
redundant even now. A's guards would keep the tree either way; B is what makes the attempt
free, and what makes the answer the one an operator can act on.

**The rule for a caller, restated to match the tree.** Go through
`DurableWorkspaceProvisionTrigger`. The justification has changed from *"a direct call
deletes the clone"* (false since `e82a120`) to *"a direct call reaches the credential
chain, re-materialises, rewrites the record, and fails with a collision instead of with
the answer"*. It is still the only correct entry point, for a weaker reason than the one
this file used to give.

## The executable proof

Read the test rather than this file when you need the behaviour. **Note which rows run
real `git` and which do not — that distinction was previously left to the reader, and
getting it wrong is how this file came to be wrong.**

| What is true | Where it is true, mechanically | Real `git`? |
|---|---|---|
| A second `git remote add origin` in an existing repository exits non-zero | `apps/server/test/durable_workspace_provision_trigger_test.dart` — "WHY it must refuse: a second materialisation into the same tree would DESTROY the first". Runs the `git` **binary** via `Process.runSync` in a `Directory.systemTemp` temp dir; no network, no ssh. **No materialiser and no runtime are involved** — it asserts a property of `git`, not of this repository's code. | yes |
| **Guard B** is total and unconditional within the trigger, and the capability is gated where the trigger does not reach | same file, two tests. "there is no destructive path in this lane to reach deliberately — as a CLOSED SET of calls the trigger may make" enumerates every `runtime.…` / `provisioner.…` the trigger can invoke, so a NEW call of any name fails. "the destructive CAPABILITY is named outside the mechanism only by the trigger" then scans every `.dart` file under `lib/` for `DurableWorkspaceRuntime` / `DurableWorkspaceProvisioner` / `DurableWorkspaceMaterializer` and for a `.provision(` call on any receiver other than `trigger`. Its exemption is the trigger **class** — its declaration, the doc comment above it, and its body — and **not** the file: exempting all of it meant a direct `runtime.provision(` planted in a private helper anywhere else in that file passed both gates and every test in the suite. | no |
| A second call through the trigger changes nothing at all | same file — "the second call is refused and changes nothing", comparing the stored record before and after. | no |
| It is deterministic, not a first-call-only guard | same file — "DETERMINISTIC across any number of calls". | no |
| **Guard A** — a root this call did not create is never destroyed, and a root it did create still is | `apps/server/lib/src/baseline/durable_workspace_materializer_test.dart`, group `a product root this call did not create is never destroyed` — 10 tests against **real git** behind a recording shim. The headline test asserts tree **content** survived (`git rev-parse HEAD` unchanged, the commit still in `git log`), not merely that an exception was thrown. The `COUNTERPART` test asserts the inverse, so "stop deleting" cannot be satisfied by "stop cleaning up". **This is A1B's file and A1B's lane's subject; do not re-pin it here.** | yes |
| **`DurableWorkspaceRuntime.provision()` has no idempotence guard of its own** — the half of the attribution that is still true | `apps/server/test/durable_workspace_provision_trigger_test.dart`, group `THE ATTRIBUTION, PINNED`. Builds the REAL `DurableWorkspaceRuntime` through its real factory, bypasses `DurableWorkspaceProvisionTrigger` entirely, calls `runtime.provision(…)` twice, and asserts `materializations == 2`, `requestedRoots == [root, root]`, the second call returns normally, and the one onboarding row is reused with a bumped version. **The materialiser here is `_RecordingDurableMaterializer`, a test double that never reaches `SshDurableWorkspaceMaterializer` and never spawns `git`.** | no |

### About that last row, precisely

It is **not** vacuous — it pins a true and still-load-bearing claim — but it is **blind to
guard A by construction**, and this file previously let a reader believe otherwise. Two
things it does and does not establish:

- **DOES establish:** `DurableWorkspaceRuntime.provision()` has no guard of its own. It
  re-materialises into the same root and rewrites the record. That was true before
  `e82a120` and is true after it — `e82a120` changed the layer below, not this one.
  That is exactly why the row is worth keeping while the first half of the claim it
  used to carry had to go.
- **DOES NOT establish:** anything about `SshDurableWorkspaceMaterializer`. The
  materialiser is a double, so a guard added there can never turn this test red. The
  earlier version of this row carried an explicit contract — *this test is expected to go
  red when the guard lands* — and the guard landed at a layer this test replaces. The
  contract is removed rather than left standing, because a red test that never goes red
  teaches a reader that the pins here are live.

Non-vacuity is mechanical, not courtesy: the count is asserted as `2` with a reason
string that tells the reader to rewrite **this file first** and then the number. If a
future change makes the runtime refuse, that assertion goes red with instructions
attached, rather than passing silently.

### What these gates do not prove

Stated rather than implied: a call that reaches the capability without naming any of the
three types and without spelling `.provision(` on a recognisable receiver — for example
through an object handed in from elsewhere in the process — is not something a grep over
source text can see. Nor is a `.materialize(` on a durable materializer that arrives
without the type being named. What the gates do is fail CI on the ordinary accident: a
new lane calling `DurableWorkspaceRuntime.provision()` because it is the obvious API to
call, from anywhere in the lane, including a helper inside the file the guard lives in.
Review still owns the rest.

The `git remote add origin` test asserts a property of `git` rather than of this
repository's code. If it ever fails, both guards have lost the mechanical reason they
have and need a real one before anyone relaxes them.

## RESIDUAL: guard A assumes a single writer per product root

**`materialize()` is not re-entrant, and guard A does not make it so.** The provenance
test reads `rootPreExisted` and claims `createdRoot` with no lock, no atomic claim and no
compare-and-set. Two **concurrent** calls on one root therefore both observe
`rootPreExisted == false`, both claim ownership, and the loser's `on Object` handler
destroys a tree the winner is writing into. A1B measured this: **6 of 6 races destroy
the root.** A `rootPreExisted` check answers "did anything exist when I looked?", and
under concurrency the answer is true for every caller at once.

**The precondition guard A actually needs is: one writer per `$workspaceRoot/$productId`
at a time.** Hold it, and guard A is sound. Drop it, and guard A fails open on exactly
the case it was written for.

- **The authoritative statement of this rule is the merge commit message of `e82a120`**
  ("Residual, recorded: two concurrent calls on one root both observe
  `rootPreExisted == false` and both claim ownership; measured 6/6 races destroy the
  root. Zero production reachability today. Needs its own ticket.").
- **`docs/engineering/learning/destroy-provenance-not-cleanup-on-failure.md` states the
  rule without this precondition** — it says `materialize` is "not re-entrant" and stops
  there. That file is A1B's and is the reference for *why* provenance is the right test;
  this file is the one a future lane is most likely to read *before* calling
  `materialize()` or `provision()` directly, which is why the precondition is recorded
  here as well as there.
- **Reachability today is zero**: the trigger is called once, at boot, from one
  instruction, before any scheduler exists. Do not rely on that as the control — it is
  an accident of the current call graph, not a guard.
- **Not fixed here, deliberately.** Adding a lock is a concurrency design decision with
  its own failure modes (what to do when the holder dies), it is `lib/src/baseline/**`
  which this lane does not own, and it needs its own ticket and its own review. This is
  recorded and routed, not worked around.

## What is NOT decided here

**How long a durable clone lives, and who presses it, remain open** — OD-7.2 and OD-7.3,
as A1's own startup banner already states (`reclamationPolicy: none`). Re-pinning a
product to a newer commit is a real need and is deliberately not this lane's job. A lane
that needs to reclaim a clone has to answer those two questions first, and an answer is a
human decision, not a `git` invocation.

Until then, neither guard has removed the open question. B says a second attempt is
refused; A says a tree this call did not create is left alone. Neither says what should
happen to a clone that should be replaced, because nobody has decided.

---

## Related facts verified while building this

- **No authenticated arbitrary-ref resolver exists in the platform.** `PinnedRevisionResolver` /
  `SnapshotPinnedRevisionResolver` (`apps/server/lib/src/baseline/baseline_onboarding_sweep.dart`)
  resolves the remote's `HEAD` and nothing else; there is no `git ls-remote` implementation anywhere
  under `apps/server/lib` or `packages/`. Resolving a named ref would mean holding the product's
  deploy key behind its confirmed host key in a caller — which is ADR 0018 A2, the gap that was
  closed. A caller in front of `DurableWorkspaceRuntime` therefore cannot resolve `main`, and refuses
  it by name instead. (`PROJECT_FACT`; the design consequence is reported, not adopted here.)
- **`OnboardingRecord.gitRevisionPattern` (`^[0-9a-f]{40}$`) is the platform's one definition of a
  pin.** The trigger validates against it rather than a pattern of its own, so the caller and the
  column it writes cannot drift apart. Abbreviated SHAs and uppercase hex are refused even though
  `git` accepts both.
- **A durable clone can hold unreviewed commits**, which is the reason "re-provision" is not a
  neutral verb anywhere near this subsystem — and the reason guard A is measured by whether a
  commit *survived*, not by whether an exception was thrown.