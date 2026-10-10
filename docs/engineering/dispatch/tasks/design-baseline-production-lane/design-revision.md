# Design Revision #1 — Automated Baseline Production with Structural Producer/Verifier Separation

| Field | Value |
|---|---|
| `revision_id` | `F22EC933-E9AB-4A0B-8904-C987EE1B1951` |
| `brief_id` | `9E045515-404E-4036-864A-FBFB0B3F6B88` (inline; no prior Design Brief exists for this work item) |
| `revision_number` | 1 |
| `status` | `UNDER_REVIEW` |
| `risk_level` | **3** |
| `branch` | `design/baseline-production-lane` |
| `base_sha` | `889eee2` |
| `head_sha` | `889eee2` (design-only lane; no production file is modified by this revision) |
| `created_by` | `design-agent` |
| `created_at` | `2026-10-10T01:37:54Z` |

---

## 0. Scope of this document

This is a **design**. It contains proposed diffs **as text**. No production source, generated file,
test, or schema in this repository is modified by this revision.

The dispatch's ten questions are answered in §3. Four verified findings that change the premises
are in §2. One question cannot be answered without human authority and is escalated as **HD-1** in
§4.

---

## 1. Problem statement

A registered product becomes governed only after a baseline is proposed, verified, and approved by a
human. Today the first baseline is authored by one operator running one command by hand
(`apps/server/bin/onboard_shipit_dev.dart`). The operator's question — *"how would another product
become governed?"* — has the answer **"someone remembers to run a dev script."** That is a missing
capability, not a documentation gap.

Worse, the condition that is supposed to make the missing capability safe to automate does not hold.
`ProductGuard.baselineVerifiedIndependently` is the guard that stands between "an agent asserted
something" and "a human is asked to approve it". It currently tests that a string was written in a
field. Closing that is not a hardening task; it is a **security remediation**, and it is the reason
this revision is Risk Level 3.

---

## 2. Verified findings that change the dispatch's premises

All four were verified by reading the code at `889eee2`. They are stated here because each one
changes what the implementation must do.

### F-1 — `verifyBaseline` is an exposed RPC whose wire default is the permissive kind

The dispatch describes the weakness as a caller omitting a default parameter. That is true but it is
not the worst of it. The method is also a **Serverpod endpoint**:

```dart
// apps/server/lib/src/endpoints/product_registry_endpoints.dart:557-560
Future<ProductDetailView> verifyBaseline(
  Session session, {
  required String productId,
  required String baselineId,
  required String verifiedBy,
  String kind = 'platform_verified_evidence',
})
```

and the control-plane client calls it with the permissive value hardcoded:

```dart
// apps/control_plane/lib/data/control_plane_repository.dart:1081
await _client.productRegistryEndpoints.verifyBaseline(
  productId: productId, baselineId: baselineId,
  verifiedBy: verifiedBy,
  kind: 'platform_verified_evidence',
);
```

So the boundary is not "a CLI convention that could be bypassed by the next caller". It is a
**remote self-attestation path**: any client that can reach the endpoint writes an arbitrary
`verifiedBy` and an arbitrary `kind` and unlocks `ProductGuard.baselineVerifiedIndependently`.

**Blast radius.** The guard is required by two transitions
(`packages/workflow_engine/lib/src/transitions/product_transitions.dart:89-92` and `:121-124`), so it
gates first onboarding **and** re-baselining of an already-governed product. No UI call site exists
today (`grep` finds no widget calling `verifyBaseline`), which means this surface is unused by the
product but fully reachable by any API client.

**Consequence for the design.** Item 4 is not "make the default strict". It is "**remove the ability
to mint platform evidence from the wire**", and the endpoint's only legitimate residual action
becomes *requesting* verification, never *asserting* it.

### F-2 — The invariant the whole boundary rests on is cited 11 times and written nowhere

`verifyBaseline`'s doc comment (`product_registry_engine.dart:255`) and
`isIndependentlyVerified`'s doc comment (`product_baseline.dart:93`) both attribute the rule to
**`AGENTS.md §12`**:

> *AGENTS.md §12: an agent may produce a baseline but may never attest to it.*

`AGENTS.md` in this repository **has no §12**. It has `§13 Credentials` (`AGENTS.md:65`) and the
inherited-invariants list. Citations of the phantom section:

| Location | Kind |
|---|---|
| `packages/platform_contracts/lib/src/types/product_baseline.dart:93` | production source |
| `packages/workflow_engine/lib/src/transitions/product_transitions.dart:20` | production source |
| `packages/product_registry/lib/src/engine/product_registry_engine.dart:255` | production source |
| `packages/product_registry/lib/src/exceptions.dart:185` | production source |
| `apps/server/lib/src/database/product_baseline.spy.yaml:27` | **database schema comment** |
| `apps/server/lib/src/models/product_detail_view.yaml:16`, `product_summary_view.yaml:23` | wire models |
| `apps/server/lib/src/generated/product_detail_view.dart:124`, `product_summary_view.dart:108` | generated |
| `docs/checkpoints/DESIGN-HANDOFF.md:286` | checkpoint prose (*"agents produce evidence, workers validate — AGENTS §12"*) |

This is the **same defect class AGENTS.md documents about itself for §13**:

> *Restored 2026-10-06. §13 was quoted verbatim by ADR 0018 … but §13 did not exist in this file — `AGENTS.md` had been reduced to the framework template with `Product-specific policy: TBD`. Three ADRs pointed at absent text, and the ADR 0018 carve-out was a documented mitigation that was never applied.*

**Consequence for the design.** A guard that enforces an invariant with no policy text is enforcing
an unwritten rule. The human must author §12 — escalated as **HD-2** (§4). This does not block
implementation; it blocks D4 approval.

### F-3 — The existing verifier is unreachable-by-construction once a human claim exists

`onboard_shipit_dev.dart` does perform a genuine re-derivation (lines 288-337) — but its
first-visit branch compares the wrong two fact sets:

```dart
// :324-325 — refacts are freshly-SCRAPED facts only
final recheckHash = baselineContentHashV3(refacts);
final reproduced = recheckHash == proposed.contentHash;
```

while `proposed.contentHash` on the merge path is computed over **scraped + human** facts:

```dart
// :205-213 — the merge path the same function takes on any re-run after a human claim
proposed = currentProposed.copyWith(
  facts: [...scrapedFacts, ...humanFacts],
  contentHash: baselineContentHashV3([...scrapedFacts, ...humanFacts]),
  verifiedAt: null, verifiedBy: null, verificationKind: null,   // <- clears verification
);
```

The merge branch clears `verifiedAt`, so on the next pass line 298 enters the first branch, and line
325 compares a scraped-only hash against a scraped+human hash. Those can never be equal →
`exit(5)`.

The `else` branch at `:354-359` gets it right — it compares the scraped subset on both sides. So the
reachable failure is:

> **Run the script → a human adds a claim → run it again → it always fails, with a message blaming
> the repository.**

**Consequence for the design.** "What is comparable" must become an explicit, shared contract rather
than an inline comparison that two branches implement differently. This is the direct justification
for the `comparableSubsetHash` in §3.3/§3.4.

### F-4 — `JobType.onboardProduct` already exists and nothing consumes it

The dispatch asks (item 6) whether to add a `JobType`. It does not need to be added — it already
exists and already means exactly this work:

```dart
// packages/platform_contracts/lib/src/enums/job_type.dart:15-18
/// Onboard a Product: clone repository at pinned revision, run baseline
/// build + test, write WorkspaceDescriptor. Runs independently of any
/// work item; scoped by productId via the onboarding record.
onboardProduct('onboard_product'),
```

`ControlPlaneService.triggerOnboarding` enqueues it (`control_plane_service.dart:1804-1870`) with a
proper `dedupeKey` (`onboarding:$productId:$repositoryId:$startingRevision`). But there is **no
`JobDefinition` for it** anywhere in `packages/scheduler` (only `implementFeature`,
`designRevision`, `designReview` in `scheduler.dart:594-634` and `triageDefect` in
`triage_defect.dart:6-13`), and no lane consumes `workItemId == 'onboarding-$productId'` —
`getOnboardingStatus` reads the job back only to display it.

**`triggerOnboarding` therefore writes a job that sits `queued` forever.** This is the same silent
no-op class this work item keeps finding, and it is live today.

**Consequence for the design.** Item 6 resolves to *"reuse `onboardProduct`"*, and the real work is
**closing an existing gap**, not opening one. It also means the answer to "was this already
covered?" is no — nothing regressed; it never worked.

---

## 3. Answers to the ten questions

### 3.1 Trigger (item 1)

**Answer: two triggers, one lane, one dedupe key.** Neither trigger is the registration event
itself.

| Trigger | Why |
|---|---|
| **Operator-requested** — `triggerOnboarding`, fixed to actually run | Already exists as an API and is the escape hatch. Registration is the wrong moment: `createProduct` can precede `addRepositoryReference`, and a baseline needs a pinned revision to exist at all. |
| **Periodic sweep** — products with **no baseline row at all**, that have a usable repository reference | The operator's actual complaint. "Someone remembers to run a script" is exactly a missing sweep. |

**Why not registration:** the sweep is strictly more robust (it also covers products registered
before this feature existed), and registration-time triggering creates a race against
`addRepositoryReference`. Doing both is cheap because the dedupe key is already correct.

**Idempotency and restart.** `dedupeKey = onboarding:$productId:$repositoryId:$startingRevision` is
already computed at `control_plane_service.dart:1840`. Two properties:

- **Restart-safe.** The lane re-derives from the pinned revision; it never resumes partial state.
- **Content-safe.** The proposal path reuses an existing baseline whose `contentHash` already equals
  the freshly derived one (`onboard_shipit_dev.dart:160-164`, `:222-228`) rather than superseding it
  with an identical copy. **This logic must move into the lane verbatim** — it is correct today and
  would be a regression to lose it.

**Sweep predicate (deliberately narrow):**

```
enqueue onboarding  ⟺  product.state ∈ {draft, baselinePending, baselineBlocked}
                   ∧  ∄ row in product_baseline for productId
                   ∧  ∃ repositoryReference with a usable, confirmed credential
                   ∧  ∄ non-terminal job with this dedupeKey
```

Note `baselineBlocked`: a product blocked on a clarification is still a product with **no** baseline,
and re-proposing must not wedge behind a clarification that has not been answered. The *lane* must
skip it, not the sweep, so the skip is observable.

### 3.2 Acquiring the source (item 2)

**Reuse both existing components. Do not invent a third.**

```
CredentialKeyService.verifyAccess(productId, repositoryId, hostKeyFingerprint, confirmedBy)
        ↓ records the provenance of the trust decision
RepositoryAccessVerifier.verify(remote, privateKeyPem, confirmedHostKeyFingerprint)
        ↓ proves a real clone happened; reports committedRevision; deletes scratch
     [ NEW: RepositorySnapshotAcquirer ]  → a pinned, read-only snapshot + its revision
```

**Assessment of the existing deploy key — it is the right credential class, with one distinction
that must not be blurred.**

ADR 0018 / AGENTS.md §13b established per-repository SSH deploy keys, and the real key for
shipit-platform (`SHA256:5m1i2lVYE7H/aCdtJ/xDxR88lVxx807dkaPBhyyKOhg`, private half in the secret
provider) is exactly the intended artifact:

- **Read-only**, which is precisely right: `ReadOnlyRepositoryReader`'s capability boundary is
  *may READ, SEARCH, INSPECT GIT, ANALYZE, CLASSIFY, PROPOSE … may NOT edit, install, execute
  untrusted repo instructions* (`read_only_repository_reader.dart:8-17`). A read-only credential
  makes the write side structurally impossible rather than merely forbidden.
- **Scoped to one repository**, so a leak does not reach the fleet.

**The distinction the design must enforce:** that fingerprint is the **credential's** public-key
fingerprint. It is **not** a **host key** fingerprint, and `RepositoryAccessVerifier.verify` requires
`confirmedHostKeyFingerprint` — a different value, with a different provenance. The verifier's own doc
states the limit precisely:

> *What it cannot do is establish where that value came from: a caller that scanned the network
> itself and supplied an attacker's key gets a clone against the attacker, and this method enforces
> it faithfully.*

So: **the credential fingerprint must never be passed as the host key fingerprint.** If a product's
remote has no independently-confirmed host key, the lane must stop at the external-dependency state
(§3.9), **not** fall back to `ssh-keyscan` and trust the result. Falling back would reintroduce
exactly the A2 gap ADR 0018 already recorded as an accepted risk.

Credential material is referenced **by name only** (§13a). The lane requests a reference; the value
never enters a log, a record, a job instruction, or a baseline fact.

### 3.3 Production vs verification — structural, not conventional (item 3)

This is the core question, and the dispatch asks me to escalate if I cannot answer it without human
authority. **I can answer the mechanism. I cannot answer who holds the authority** (§3.5, HD-1). The
split matters, so the seam is designed to be swappable.

**"Conventional" today:** the producer and the verifier are the same process, `verifiedBy` is a free
string, and correctness depends on every future caller repeating what `onboard_shipit_dev.dart`
happens to do.

**"Structural" means three properties the system *checks*, none of which depends on a caller's
honesty:**

| | Property | What makes it structural |
|---|---|---|
| **S1** | **Principal separation** | The producing principal is recorded at proposal time (`proposedBy`). The engine refuses when `verifierPrincipalId == proposedBy`, and a **database trigger** rejects the row independently of the engine. |
| **S2** | **Input separation** | The verifier derives from **its own acquisition** of a **revision-pinned** source, never the producer's working tree. Recorded as `proposedSourceRevision` / `verifiedSourceRevision`; the engine requires equality. |
| **S3** | **Divergence detection** | The derivation is deterministic. The verifier re-runs it and compares content hashes. A producer that **fabricates** facts yields a hash the independent derivation cannot reproduce. |

**S3 is the mechanism the dispatch asked me to evaluate, and it is already half-built** — the
re-derivation exists at `onboard_shipit_dev.dart:288-337`. Its weakness is not the idea; it is that
the result is a `stdout.writeln`, and `verifyBaseline` is then called **with no proof at all**
(`:338-342`). The proof is computed and then discarded.

**S3's residual hole, stated honestly.** Re-derivation catches *fabrication, misclassification, and
drift*. It does **not** catch a compromised producer that controls both its own source acquisition
and the verifier's input — a process that fabricates nothing and still poisons the input passes
every check. S2 narrows this (the verifier's clone is its own) but cannot close it, because both
acquisitions use the same credential and the same host. Closing that requires an execution-context
boundary, which is exactly what HD-1 asks the human.

**The precedent this follows is already in the repository.** `trigger_design_review_independence`
(`apps/server/tool/schema_bootstrap.sql:162-189`):

```sql
-- Rejects a review result whose review execution is the execution that
-- produced the revision it is reviewing. Separation of duties is a database
-- invariant here, not a convention the call sites are trusted to honour.
```

Design-review independence is enforced **in the database**. Baseline-verification independence is
enforced **by convention in one script**. That asymmetry is the actual defect, and it has a proven
remedy already verified by `verify_schema_bootstrap.sh`.

**New `JobType`:** none. Reuse `JobType.onboardProduct` (F-4). A new type would add an enum member,
a `JobDefinition`, and a lane, for a job that already exists and already means this.

**Required tick-hook change.** `lane_i_tick_hook.dart:129-143` skips every non-`triageDefect` job
with a bare `skipped++` — no log, no error. Adding a type there is the silent-no-op class again.
The fix is structural, not another `if`:

```dart
// An unhandled JobType is a configuration error, not a no-op.
final handler = _handlers[job.jobType];
if (handler == null) {
  throw UnhandledJobTypeException(job.jobType, job.jobId);
}
```

The accounting invariant `considered == skipped + handedOff` is preserved: an unhandled type is
**not** counted as skipped, because it was not skipped — it was unhandled.

### 3.4 Fixing the guard (item 4)

**The change: delete the caller's ability to name the kind.** Today `kind` is a parameter with a
permissive default; on the wire it is a string parameter with a permissive default. The fix is to
make it **impossible to express** a platform verification without producing a proof the engine
validates.

#### Layer 1 — Dart contracts and engine

```dart
// packages/platform_contracts/lib/src/types/baseline_verification.dart  (NEW)
sealed class BaselineVerificationProof {
  const BaselineVerificationProof();
}

/// Proof that a verifier principal, distinct from the producer, re-derived the
/// baseline from its own revision-pinned acquisition of the source.
final class PlatformReDerivationProof extends BaselineVerificationProof {
  const PlatformReDerivationProof({
    required this.verifierPrincipalId,
    required this.sourceRevision,
    required this.comparableSubsetHash,
    required this.comparableFactCount,
    required this.derivationAlgorithmVersion,
  });

  final String verifierPrincipalId;
  final String sourceRevision;
  final String comparableSubsetHash;
  final int comparableFactCount;
  final String derivationAlgorithmVersion;
}
```

```dart
// packages/product_registry/lib/src/engine/product_registry_engine.dart
Future<ProductBaseline> verifyBaseline({
  required String productId,
  required String baselineId,
  required BaselineVerificationProof proof,   // was: verifiedBy + kind with a default
  DateTime? now,
}) async {
  final baseline = await _store.readBaseline(baselineId);
  _ensureOwned(productId, baseline.productId, 'baseline $baselineId');

  // S1 — a producer may never attest to its own work.
  if (proof.verifierPrincipalId == baseline.proposedBy) {
    throw SelfVerificationRefusedException(baseline.baselineId, proof.verifierPrincipalId);
  }
  // S2 — the verifier must have verified the same revision the producer pinned.
  if (proof.sourceRevision != baseline.proposedSourceRevision) {
    throw BaselineSourceDriftException(baseline.baselineId);
  }
  // S3 — the re-derivation must reproduce the baseline's comparable content.
  if (proof.comparableSubsetHash != baseline.comparableSubsetHash) {
    throw BaselineDivergenceException(
      baseline.baselineId, baseline.comparableSubsetHash, proof.comparableSubsetHash);
  }
  // A stale algorithm cannot attest to today's facts.
  if (proof.derivationAlgorithmVersion != currentDerivationAlgorithmVersion) {
    throw StaleDerivationAlgorithmException(proof.derivationAlgorithmVersion);
  }

  return _store.saveBaseline(
    baseline.copyWith(
      verifiedAt: t, verifiedBy: proof.verifierPrincipalId,
      // `kind` is DERIVED from the proof type. There is no caller-supplied kind.
      verificationKind: EvidenceKind.platformVerifiedEvidence,
      verifiedContentHash: proof.comparableSubsetHash,
      verifiedSourceRevision: proof.sourceRevision,
      updatedAt: t, version: baseline.version + 1,
    ),
    expectedVersion: baseline.version,
  );
}
```

#### Layer 2 — the guard itself fails closed

```dart
// packages/platform_contracts/lib/src/types/product_baseline.dart
bool get isIndependentlyVerified =>
    verificationKind == EvidenceKind.platformVerifiedEvidence &&
    verifiedBy != null &&
    verifiedBy!.isNotEmpty &&
    verifiedAt != null &&
    // NEW — fail closed on all three. A missing field fails; only a proven,
    // distinct, hash-reproduced verification passes.
    verifiedBy != proposedBy &&
    verifiedContentHash != null &&
    verifiedContentHash == comparableSubsetHash &&
    verifiedSourceRevision != null &&
    verifiedSourceRevision == proposedSourceRevision;
```

Every added term is a **conjunct**, so a row written by old code — which has none of the three new
columns — evaluates to `false`. **Legacy rows fail closed.** That is the intended behaviour, and it
is the single most disruptive consequence of this revision (§3.9).

#### Layer 3 — the wire can no longer mint platform evidence

```dart
// apps/server/lib/src/endpoints/product_registry_endpoints.dart
/// Records platform-verified evidence against a proposed baseline.
///
/// [kind] is REMOVED. A caller cannot name an evidence kind over the wire,
/// because naming one is what F-1 exploited.
Future<ProductDetailView> verifyBaseline(
  Session session, {
  required String productId,
  required String baselineId,
  required String verifiedBy,
})
```

With `kind` gone from the wire, the endpoint **cannot construct a
`PlatformReDerivationProof`** — that requires a `comparableSubsetHash` only the server-side lane
can compute. The endpoint's honest residual value is *recording an operator's
`agentClaimedEvidence`* (which never satisfies the guard) and *requesting a verification job*.
It loses the power to forge, and keeps the power to ask.

#### Layer 4 — database enforcement (mirrors the design-review precedent)

```sql
-- apps/server/tool/schema_bootstrap.sql
CREATE OR REPLACE FUNCTION "enforce_product_baseline_verification_independence"()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_proposed_by text;
BEGIN
  SELECT "proposedBy" INTO v_proposed_by
  FROM "product_baseline" WHERE "baselineId" = NEW."baselineId";

  IF NEW."verificationKind" = 'platform_verified_evidence'
     AND v_proposed_by IS NOT NULL
     AND NEW."verifiedBy" = v_proposed_by THEN
    RAISE EXCEPTION 'Verifier % cannot attest to a baseline it produced % (independence violation)',
      NEW."verifiedBy", NEW."baselineId";
  END IF;

  IF NEW."verificationKind" = 'platform_verified_evidence'
     AND (NEW."verifiedContentHash" IS DISTINCT FROM NEW."comparableSubsetHash") THEN
    RAISE EXCEPTION 'Platform verification of % requires the re-derived hash to equal the comparable subset hash',
      NEW."baselineId";
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER "trigger_product_baseline_verification_independence"
BEFORE INSERT OR UPDATE ON "product_baseline"
FOR EACH ROW EXECUTE FUNCTION "enforce_product_baseline_verification_independence"();
```

**What the database can and cannot enforce — stated honestly.** The trigger compares two *columns of
the same row*, which is why the design records the re-derived hash rather than a boolean. It
**cannot** re-run the derivation: `baselineContentHashV3` is Dart
(`packages/product_registry/lib/src/engine/baseline_content_hash_v3.dart`) and has no SQL
counterpart. So the trigger enforces *"this attestation is internally consistent and not
self-signed"*, and the engine enforces *"this attestation corresponds to a real derivation from the
pinned source"*. Layer 4 is the backstop that holds even if Layer 1 is bypassed by a future caller —
it is not a substitute for it.

**Migration.** `product_baseline` gains `proposedBy`, `proposedSourceRevision`,
`comparableSubsetHash`, `verifiedContentHash`, `verifiedSourceRevision`, `derivationAlgorithmVersion`
(nullable). Registered in `schema_bootstrap.sql`, the next `migrations/<ts>/migration.sql`, and
checked by `verify_schema_bootstrap.sh`, which currently reports **20 `OK:` assertions, exit 0**.

**What breaks, concretely.** ~28 `verifyBaseline` call sites exist (`grep` across `packages` and
`apps`), including `product_registry_endpoints.dart:557`, `control_plane_service.dart:630`,
`control_plane_repository.dart:1076`, `onboard_shipit_dev.dart:338`, and ~20 tests. **Every one of
them currently relies on the permissive default**, which means the present test suite proves nothing
about independence.

Recommended migration, not a compatibility shim: replace the signature outright and give the tests
**one** honest helper,

```dart
// packages/product_registry/test/support/baseline_verification.dart  (NEW)
Future<ProductBaseline> verifyBaselineWithProof(
  ProductRegistryEngine engine, {
  required String productId,
  required String baselineId,
  required String verifierPrincipalId,   // distinct from the fixture's producer by default
  required String comparableSubsetHash,  // read from the baseline itself
  ...
})
```

A shim that keeps the old signature would keep the old hole, and a shim that fabricates a
trustworthy-looking proof would make tests pass against a fiction. Both are worse than a hard break
with 20 mechanical call-site updates.

### 3.5 What legitimately issues `platformVerifiedEvidence` (item 5) — **ESCALATED, HD-1**

The dispatch asked me to evaluate, at minimum, the option that the verifier independently
re-derives the baseline from the same source and compares content hashes, "so a producer that lies
is caught by divergence rather than by policy." I evaluated it; it is **S3 above**, and I recommend it.
**But I am not authorised to decide that it is `platformVerifiedEvidence`, and I am escalating
rather than choosing.**

#### What the options are

| | Option | Assessment |
|---|---|---|
| **A** | Deterministic re-derivation under a distinct principal over its own pinned acquisition | **Recommended.** Catches fabrication, misclassification, drift. Residual hole: a compromised process controlling both acquisitions. |
| **B** | Distinct execution context (separate worker/service/process) in addition to A | Closes "same process". Does **not** close "same credential, same host". Materially more infrastructure. |
| **C** | A human verifies | Defeats the entire purpose of this work item — the operator asked to remove a manual step, not add one. |
| **D** | A second agent with a different name | **Rejected.** An agent asserting it did not lie is an agent's own claim — the thing §13's evidence enum exists to distinguish from platform verification. A renamed agent is the F-1 hole with better branding. |

#### Why this needs human authority

1. **It defines a term that keys a governance gate.** `EvidenceKind.platformVerifiedEvidence` is the
   only value that satisfies `ProductGuard.baselineVerifiedIndependently`. Choosing what may mint it
   is choosing who can govern a product.
2. **The invariant has no policy text** (F-2). §12 is cited 11 times and does not exist. Deciding
   its content is authoring human policy.
3. **The answer determines whether a single compromised worker can self-certify.** A is materially
   weaker than B on precisely the threat that matters, and I have no authority to accept that
   residual risk on the fleet's behalf.

**My recommendation, offered as input and not as a decision: A now, B as scoped follow-on**, with
the residual hole of A recorded explicitly rather than left implicit. If the human prefers B, the
only structural change is *where* the verifier executes — S1/S2/S3, the guard, the trigger, and the
RPC lockdown are unchanged. **That is why the seam is where it is.**

#### HD-1 — routed to the human

> **Question (atomic, single proposal):** Does a deterministic platform re-derivation — executed
> under a verifier principal distinct from the producer's, over a source revision the verifier
> acquired itself, compared by content hash — constitute `platformVerifiedEvidence`?
>
> **A.** Yes; a distinct execution context is not additionally required.
> **B.** No; verification additionally requires an execution context distinct from production.
>
> **Context:** §3.3/§3.4 design the mechanism; `verifyBaseline` currently accepts any caller's
> `kind` (F-1); the invariant it enforces has no policy text (F-2).
> **Evidence:** this revision §§2, 3.3, 3.4; `schema_bootstrap.sql:162-189` (the analogous
> `trigger_design_review_independence`, which the human already accepted as a database invariant).
> **Blocking:** Gate D4 approval of this revision. **Does not block** implementation of
> §§3.1, 3.2, 3.6, 3.7, 3.8, 3.10, which are independent of the answer.

#### HD-2 — also routed, non-blocking for implementation

> **Question:** Who authors `AGENTS.md §12`, and what is its text? Eleven citations (F-2), including
> a database schema comment, currently point at a section that does not exist — the same defect class
> AGENTS.md documents for §13. The guard this revision hardens enforces §12; §12 needs to exist.
>
> **Blocking:** D4 approval. **Does not block** implementation.

### 3.6 New `JobType`, or reuse (item 6)

**Reuse `JobType.onboardProduct`** (F-4). The enum already carries the exact semantics. Two required
changes:

1. **Register the missing `JobDefinition`** (`packages/scheduler/lib/src/baseline_product.dart`):
   ```dart
   const JobDefinition onboardProductDefinition = JobDefinition(
     jobType: JobType.onboardProduct,
     requiredRole: AgentRole.implementer,
     requiredCapabilities: {WorkerCapability.linux, WorkerCapability.git},
     entryStates: {WorkItemState.designNotRequired},
     priority: JobPriority.high,
     maxAttempts: 2,
   );
   ```
   Note `triggerOnboarding` currently writes the job **directly to the store**, bypassing the
   scheduler entirely. The lane must be reachable from the scheduler, or the job will keep sitting
   queued (F-4).
2. **Extend the tick hook** to a per-type dispatch table, with an unhandled type throwing rather
   than incrementing `skipped` (§3.3).

**Nothing is added to the enum**, so no `JobType.fromWire` compatibility shim is needed and no wire
value changes.

### 3.7 What remains human (item 7)

The human gate is **unchanged and unchanged in strength**:

```dart
// packages/workflow_engine/lib/src/transitions/product_transitions.dart:95-98
( ProductState.baselineReview, ProductState.governed ): [
  ProductGuard.baselineApproved,
  ProductGuard.decisionActorIsHuman,
],
```

**Automation stops at `baselineReview` — verified-and-awaiting-approval.** The lane's terminal state
is exactly the CLI's, restated:

> *This script NEVER resolves a HumanDecision. Baseline approval is a human gate (AGENTS.md §19);
> fabricating a decider would forge the authority that makes a governed product meaningful. It stops
> at a pending decision.*

The lane may call `requestBaselineApproval` (which *creates* a PENDING `HumanDecision`) and may
never resolve one. If any code path in the lane can produce a `RESOLVED` decision with a non-human
actor, that is a review-blocking finding — the same invariant the framework states as *"An agent
cannot promote itself."*

### 3.8 Product-agnosticism (item 8)

Designed against a **second hypothetical product** — call it **Product B**: a Dart/Flutter monorepo
in its own repository, on a different host, with its own deploy key and its own confirmed host key,
registered after Product A is already governed.

**Design rule, enforceable as a grep gate:**

> No file under `apps/server/lib/src/baseline/` may contain the substrings `shipit`, `SHIPIT_`,
> `SHIPIT_PRODUCT_ID`, `SHIPIT_REPOSITORY_PATH`, or a hardcoded filesystem path.

This is stricter than the CLI, which at least takes `argv[0]` first (`onboard_shipit_dev.dart:37-39`).
In the lane, **`productId` and `repositoryId` are required with no defaults** — a default is how a
product silently inherits another's configuration, and the operator's complaint was that the script
looked tailored to one product.

**Product-agnostic properties this design has that the CLI does not:**

| | CLI today | Lane |
|---|---|---|
| Product identity | `argv[0]` or `SHIPIT_PRODUCT_ID`, default `'shipit-platform'` | Required, from the job |
| Source | Local directory (`SHIPIT_REPOSITORY_PATH`) | Remote, resolved from the repository reference, revision-pinned |
| Credential | None — assumes filesystem access | Named credential reference + confirmed host key |
| Revision | "Whatever is on disk now" | Pinned; recorded on both proposal and verification |

Product B needs no code change and no ShipIt-specific configuration. Its only onboarding cost is
registering its repository reference, its credential reference, and its confirmed host key — which
is already the shape of `addRepositoryReference` and `verifyAccess`.

### 3.9 Migration and rollout (item 9)

**Legacy rows fail closed — state this plainly.** After Layer 2, any `product_baseline` row without
`verifiedContentHash`/`verifiedSourceRevision` evaluates `isIndependentlyVerified == false`. Such a
row **cannot open the approval gate** and will raise `BaselineNotVerifiedException`. This is
correct — those rows were self-attested — but it means:

- Any product in `baselineReview` or `baselineBlocked` state whose baseline predates this change
  **must be re-verified** by the new lane before it can advance.
- The re-verification is **non-destructive**: it re-derives from the pinned revision and writes a new
  `version` on the same row. No baseline is deleted; the facts are untouched.
- Until each product is re-verified, it sits at `baselineBlocked` with a recorded reason, which is
  the honest state.

**Rollout order** (each step independently observable, no step silently mutates a gate):

1. **Schema** — additive nullable columns, trigger, bootstrap + migration + `verify_schema_bootstrap.sh`.
   No behaviour change. Guard still passes on rows that have the columns; legacy rows now fail closed.
2. **Contracts + engine** — proof-based `verifyBaseline`, fail-closed guard. All call sites updated
   in the same commit so the tree never contains a signature no caller can satisfy.
3. **RPC lockdown** — `kind` removed from the wire; control-plane client updated; regenerated.
4. **Credential acquisition + lane** — new files only; no existing behaviour changes. The sweep is
   **off by default** at this step.
5. **Sweep enabled** — the first step that changes product state, gated on observing the lane
   succeed end-to-end on Product A.
6. **Re-verification of legacy rows** — driven by the sweep, one product at a time.

**External dependency state, following the `lane_e` precedent exactly.** When the source cannot be
acquired — no credential, credential not `verified`, no independently-confirmed host key — the lane
records, on the job:

```dart
const String baselineSourceCredentialKey = 'baselineSourceCredential';
const String externalBaselineSourceDependency = 'EXTERNAL_BASELINE_SOURCE_DEPENDENCY';
const String baselineSourceCredentialUnavailable = 'unavailable';
```

with the same honesty `lane_e_design_remediation_work_item.dart:12` states:

> *`unavailable` means the runtime does not exist in shipit-platform, not that a human declined to run it.*

Re-worded for this lane: **`unavailable` means no usable, host-confirmed credential is registered
for this repository — it does not mean an operator refused, and it must not be presented as a
product that failed onboarding.** The product stays `draft`; no gate opens; the reason is visible.

**One thing that is NOT external.** There is a design-governance-runtime dependency recorded by
`lane_e` (`EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`). Baseline production has no such dependency — the
runtime needed to derive and verify a baseline **exists today**
(`ReadOnlyRepositoryReader`, `MaturityClassifier`, `RepositoryAccessVerifier`, `ProductRegistryEngine`).
So this lane must **not** import that pattern out of habit. Recording `unavailable` for something that
*is* available would be the dishonest-terminal-state defect in a new place.

### 3.10 Verification plan (item 10)

The negative case is the point. A producer that fabricates a baseline must be caught — and the test
must assert **which layer** caught it, or a passing suite will not distinguish "the guard works"
from "the guard was never consulted".

**Positive**

| ID | Test | Layer |
|---|---|---|
| V-1 | Valid proof → `isIndependentlyVerified == true`, gate opens | Engine |
| V-2 | Verification recorded with `verificationKind == platformVerifiedEvidence` and a **derived** kind (no caller param) | Engine |
| V-3 | The lane takes a product from registered to `baselineReview` with a PENDING decision | Integration |
| V-4 | Re-running the lane on unchanged source reuses the baseline (no revision spam) | Lane |
| V-5 | Restart mid-lane leaves no partial state; the job is retryable | Lane |

**Negative — the ones that matter**

| ID | Test | Expected | Layer |
|---|---|---|---|
| **N-1** | **Fabricating producer.** Facts invented, never derived from source. | `BaselineDivergenceException`; no verification written | S3 / engine |
| **N-2** | **Self-attestation.** `verifierPrincipalId == proposedBy`. | `SelfVerificationRefusedException`; **and** the DB trigger raises if the engine is bypassed | S1 / engine **+ trigger** |
| **N-3** | **Source drift.** Producer pinned rev A; verifier derives from rev B. | `BaselineSourceDriftException` | S2 / engine |
| **N-4** | **The F-1 regression.** Call the HTTP endpoint with `kind: platform_verified_evidence`. | **Parameter no longer exists**; and even without it, no proof ⇒ no platform evidence | RPC |
| **N-5** | **The default-omission regression.** Call the engine with no kind. | **No such parameter.** Compilation itself is the test | API |
| **N-6** | **Legacy row.** A pre-migration row with `verificationKind` set and no new columns. | `isIndependentlyVerified == false`; gate refuses | Guard (fail-closed) |
| **N-7** | **F-3 regression.** Baseline with a human claim + scraped facts, re-verified. | Verifies **successfully** — the comparable-subset contract, not the full-content comparison | Lane |
| **N-8** | **Stale algorithm.** Proof carries an old `derivationAlgorithmVersion`. | `StaleDerivationAlgorithmException` | Engine |
| **N-9** | **Unhandled job type.** A terminal job of a type with no registered handler. | **Throws** `UnhandledJobTypeException`; **not** counted in `skipped` | Tick hook |
| **N-10** | **Host-key confusion.** Credential fingerprint passed as host key fingerprint. | Rejected — the two are distinct fields; lane refuses | Credential |

**N-1, N-2 and N-6 are the acceptance criteria for the security finding.** If those three do not
fail closed, this work item has not succeeded regardless of what else passes.

---

## 4. Human Decisions routed (not resolved here)

| ID | Question | Blocking | Authority |
|---|---|---|---|
| **HD-1** | Does deterministic re-derivation under a distinct principal (option A) constitute `platformVerifiedEvidence`, or is a distinct execution context additionally required (option B)? | D4 approval. Does **not** block implementation. | Human — architecture/security |
| **HD-2** | Who authors `AGENTS.md §12`, and what is its text? Eleven citations point at a section that does not exist. | D4 approval. Does **not** block implementation. | Human — governance policy |

Per `aef-human-decision`, neither is resolved by this lane. No `HumanDecision` object is created,
resolved, or implied here.

---

## 5. Discoveries (per `aef-repository-learning`)

| ID | Finding | Category | Authority | Persisted here? |
|---|---|---|---|---|
| F-1 | `verifyBaseline` is an RPC whose wire default is the permissive `kind` — remote self-attestation | `ARCHITECTURE_DISCOVERY` | **Human** | Reported only |
| F-2 | `AGENTS.md §12` cited 11× (incl. DB schema), does not exist | `CONTRADICTION` (governance) | **Human** | Reported only |
| F-3 | Verifier compares scraped-only hash against scraped+human hash; fails on any re-run after a human claim | `PROJECT_FACT` | Auto (implemented in Lane 4) | Reported |
| F-4 | `JobType.onboardProduct` enqueued but has no `JobDefinition` and no consumer — sits `queued` forever | `PROJECT_FACT` | Auto (Lane 4) | Reported |
| — | `JobType.onboardProduct` already exists, contradicting the dispatch's premise that only `triageDefect` applies | `PROJECT_FACT` | Auto | Reported |
| — | Deterministic re-derivation already exists at `onboard_shipit_dev.dart:288-337`; the computed proof is discarded before `verifyBaseline` is called with none | `PROJECT_FACT` | Auto (Lane 1) | Reported |
| — | Design-review independence is DB-enforced (`trigger_design_review_independence`) while baseline-verification independence is convention-only | `WORKFLOW_IMPROVEMENT` | Independent review | Reported |
| — | `apps/server/tool/verify_schema_bootstrap.sh` — 20 `OK:` assertions, **exit 0** at `889eee2` | `PROJECT_FACT` | Auto | Executed |

**Persist:** none from this lane. This is a design-only lane; its owned path is its own task
directory. F-1, F-2 and HD-1/HD-2 exceed design authority.

---

## 6. Implementation lanes unblocked

**Non-overlapping `OWNED_PATHS`.** Generated trees are assigned to exactly one lane so no two
concurrent writers touch them.

| Lane | Scope | `OWNED_PATHS` (exclusive) |
|---|---|---|
| **L1** — Guard | Contracts + engine, fail-closed, proof API, comparable-subset contract | `packages/platform_contracts/lib/src/types/{product_baseline,baseline_verification}.dart`<br>`packages/platform_contracts/test/**`<br>`packages/product_registry/lib/src/**`<br>`packages/product_registry/test/**` |
| **L2** — Schema | Columns, trigger, migration, bootstrap drift guard | `apps/server/tool/schema_bootstrap.sql`<br>`apps/server/tool/verify_schema_bootstrap.sh`<br>`apps/server/migrations/**`<br>`apps/server/lib/src/database/product_baseline.spy.yaml`<br>`apps/server/test/**` |
| **L3** — Wire | Remove `kind` from the RPC; endpoint/service/client | `apps/server/lib/src/endpoints/product_registry_endpoints.dart`<br>`apps/server/lib/src/services/control_plane_service.dart`<br>`apps/control_plane/lib/data/control_plane_repository.dart` |
| **L4** — Lane | The lane, acquisition, scheduler definition, tick dispatch table | `apps/server/lib/src/baseline/**`<br>`apps/server/lib/src/credentials/repository_snapshot_acquirer.dart`<br>`packages/scheduler/lib/src/baseline_product.dart`<br>`apps/server/lib/src/triage/lane_i_tick_hook.dart` |
| **L5** — Generated | Regeneration **only**, after L1-L4 land | `apps/server/lib/src/generated/**`<br>`apps/control_plane/lib/generated/**` |

**Dependency edges (why these are not all parallel):**

```
L1 ──┬─→ L5
L2 ──┤
L3 ──┘   (L3 cannot compile until L1 removes the parameter; L5 regenerates after both)
L4 ─────→ L5
```

**Safe to run concurrently:** `L1 ∥ L2 ∥ L4` — disjoint paths, no shared file.
**Sequential:** `L3` after `L1`; `L5` after `L1, L2, L3, L4`.

**Prohibited parallel work:** any two of `L1/L2/L3/L4/L5` touching the same file; any lane
hand-editing `apps/server/lib/src/generated/**` (generated, per AGENTS.md); L3 before L1; L5 before
L4; **and any implementation lane resolving HD-1 or HD-2.**

**Suggested order:** `L1 ∥ L2 ∥ L4` → `L3` → `L5`, with the sweep **off** until L4 has run
end-to-end on Product A (§3.9 step 5).

---

## 7. Traceability

| Requirement / constraint | Source | Section | Status |
|---|---|---|---|
| 1 — Trigger, idempotency, restart | dispatch §90-94 | §3.1 | Covered |
| 2 — Acquire the source; deploy key; reuse verifier/ssh | §85-88, §96 | §3.2 | Covered |
| 3 — Structural producer/verifier separation | §97-99 | §3.3 | Covered; **HD-1** on the authority question |
| 4 — Fail-closed guard, no permissive default, migration | §100-103 | §3.4 | Covered |
| 5 — Who issues `platformVerifiedEvidence` | §104-108 | §3.5 | **ESCALATED — HD-1**; mechanism designed, authority not chosen |
| 6 — New `JobType` vs reuse; tick hook | §109-110 | §3.6 | Covered (reuse; F-4) |
| 7 — Human gate retained | §111-112 | §3.7 | Covered |
| 8 — Product-agnosticism | §113-114 | §3.8 | Covered |
| 9 — Migration, `EXTERNAL_*` precedent | §115-116 | §3.9 | Covered |
| 10 — Verification incl. negative case | §117-118 | §3.10 | Covered |
| Security-boundary framing | §46-48 | §1, §2, §3.4 | Covered |
| Design only; no implementation | §122-123 | Whole document | Honoured — diffs are text |
| `packages/**`, `apps/server/**`, `apps/control_plane/**` read-only | §124 | — | Honoured — 0 files modified |
| Zero Docker/Compose | §126 | §9 | Honoured |
| `verify_schema_bootstrap.sh` run + reported | §126-127 | §9 | Run — **20 OK, exit 0** |
| No Human Decision resolved | §128 | §4 | Honoured |
| Non-overlapping per-lane `OWNED_PATHS` | §134 | §6 | Honoured |

**`requirements_gaps`:** none. One item is answered as *escalated rather than decided* (item 5 /
HD-1) and one adjacent question is added (HD-2 / F-2). Neither is a gap in coverage; both are
deliberate refusals to exercise authority this lane does not hold.

---

## 8. Validation performed by this lane

| Command | Result |
|---|---|
| `git branch --show-current` | `design/baseline-production-lane` ✅ |
| `git rev-parse HEAD` | `889eee237d5b5cf5bcd82c34b07db32f03920222` ✅ (dispatch: `889eee2`) |
| `git status --porcelain` | empty — clean tree ✅ |
| `bash apps/server/tool/verify_schema_bootstrap.sh` | **exit 0**, 20 `OK:` assertions, 0 failures ✅ |
| Docker/Compose commands issued | **0** ✅ |
| Files modified outside `docs/engineering/dispatch/tasks/design-baseline-production-lane/` | **0** ✅ |

---

## 9. Risk assessment

**`risk_level: 3`**

Rationale, against the `DESIGN_GOVERNANCE.md` scale:

- **Core workflow and governance model.** This changes what may mint the sole evidence kind that
  unlocks `ProductGuard.baselineVerifiedIndependently` — the gate between an agent's assertion and a
  human being asked to approve. That is a core workflow change affecting the meaning of "governed",
  not a feature-level UX change.
- **It alters an existing invariant.** The dispatch states this outright (§103). The guard is made to
  **fail closed**, which flips the evaluation of every legacy row (§3.9). A change that turns
  previously-passing rows into failures is the definition of consequential.
- **It is a security-boundary remediation.** F-1 is a live reachable self-attestation path, not a
  theoretical one.
- **Level 3 additionally requires architecture approval**, which is exactly what HD-1 asks for.

A Level 2 reading was considered and rejected: "no user-facing flow changes" is true of the UI, but
the risk taxonomy keys on workflow and governance model, and both change. Understating it here would
put a security remediation through a lighter gate than it deserves.

**Implementation feasibility: HIGH.** Every mechanism is either already present
(`ReadOnlyRepositoryReader`, `MaturityClassifier`, `RepositoryAccessVerifier`,
`CredentialKeyService`, `triggerOnboarding`, the `JobType` enum member, the re-derivation itself,
`trigger_design_review_independence` as a template) or is additive Dart/SQL with no new dependency.
The only unresolved input is HD-1, and the seam is designed so both answers are implementable.

**Design system compliance: N/A → PASS by non-applicability.** This revision has no UI surface. It
introduces no new view, token, or component. *(The framework scale has no `N/A`; recorded as PASS
with the justification that there is nothing to comply with. An independent reviewer may prefer
`UNKNOWN`.)*

**UX/accessibility: N/A → PASS by non-applicability.** No user-facing surface is added or changed.
The operator-visible change is that a new action becomes *possible* (register a repository reference
and a credential, then wait for the sweep) — a workflow change with no rendered UI. The dashboard
already renders `product_detail_view`'s `baselineVerifiedIndependently` field; this revision changes
when that flag becomes true, not how it is rendered, so **no accessibility regression is possible
and no WCAG criterion is engaged**.

---

## 10. Independent review focus

Suggested, not directed — the reviewer owns the verdict.

1. **HD-1 is correctly framed** as atomic, with a real recommendation and no smuggled decision.
2. **Whether "fail closed on legacy rows" is acceptable collateral damage** (§3.9) or should be
   staged behind a backfill.
3. **Whether Layer 2 (trigger) is honest** about what a database can and cannot enforce (§3.4) — the
   claim is that it cannot re-derive, and that Layer 1 is not optional.
4. **Whether the ~28-call-site hard break** (no compatibility shim) is right, or whether the shim's
   risks are acceptable.
5. **N-4 and N-5 as written** actually test the F-1 regression, rather than testing the new code
   path and leaving the old one live.
6. **Whether §3.9's "not external" paragraph** is correct that baseline production has no runtime
   dependency, and therefore must not borrow `lane_e`'s pattern.