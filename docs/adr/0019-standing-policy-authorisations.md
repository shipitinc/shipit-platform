# ADR 0019: Standing Policy Authorisations

## Status
Proposed

## Context

ADR 0013 makes human gates durable workflow states with strong semantics:
entering a gate **terminates execution** — no agent, worker, or scheduler runs
until a human resolves it. That is correct for consequential decisions, and
ADR 0012 already scopes gates narrowly: *"human gates only where required
(production)"*.

Checkpoint 006 design review surfaced a class of action that is neither clearly
gated nor clearly free: repeated, low-consequence actions that a human would
approve every time, in the same way, for the same reason. Pushing a result to a
product's own repository is the motivating example. Gating each one has two
failure modes:

1. **It terminates execution inside an iteration loop.** A
   `push → CI fails → fix → push` cycle would hit the gate on every pass,
   halting the scheduler repeatedly for one logical unit of work.
2. **It degrades the decision itself.** A human asked to approve the same thing
   twenty times stops reading. Approval becomes a reflex, which is worse than no
   gate at all because the durable record still claims a considered decision was
   made.

Removing the gate entirely solves throughput but loses attribution: the record
no longer links "a human authorised this" to "this happened".

The existing model already has the right primitive. A `HumanDecision` is
durable, signed, and carries a rationale. What it lacks is **scope beyond a
single work item**.

## Decision

**A `HumanDecision` may authorise a class of future actions rather than one
action. Every action taken under it cites the authorising decision in the
durable record.**

A standing policy is not a configuration flag. It is a decision, with all the
properties ADR 0013 requires — `decisionId`, `decider`, `choice`, `rationale`,
`timestamp`, `signature` — plus a scope and a lifecycle.

- **Scope is explicit and bounded.** A policy names the `decisionType` it
  authorises and the subject it applies to (a product, a class of work). It
  cannot be open-ended.
- **Every authorised action cites its policy.** The durable record for the
  action carries the `decisionId` of the policy that permitted it. "Why did this
  happen without me?" is always answerable, and always answerable with a
  signature.
- **Policies are revocable, and revocation is itself a decision.** Revoking is
  recorded with its own rationale and signature. The audit trail shows when the
  authorisation existed and when it stopped.
- **Policies do not apply retroactively.** Actions taken before the policy
  existed are not re-attributed to it.
- **Policies cannot authorise production promotion.** ADR 0012's production gate
  is not delegable. A standing policy may cover pushes, merges, and comparable
  reversible actions; it may not cover deployment to production, baseline
  approval, or product offboarding.
- **Policy creation is itself gated.** Creating a standing policy is a
  consequential decision and enters a normal ADR 0013 gate.

## Relationship to batching

Batching and standing policy solve adjacent problems and are not alternatives.

- **Batching** reduces the *number of interactions* for decisions that still
  require reading. It is constrained: only items of identical `decisionType`
  **and** identical system recommendation may be batched, so a batch can never
  sweep in an item the system did not recommend. Each item is still recorded as
  its own signed decision, sharing one rationale and a `batchId`.
- **Standing policy** removes the interaction entirely for a class of action the
  human has already decided about once.

Batching is for exceptions. Policy is for the steady state.

## Consequences

### Positive

- Throughput is no longer bounded by human attention for routine reversible
  actions, while attribution is fully preserved.
- The durable record gains a stronger claim than today: not merely "this
  happened" but "this happened under authorisation X, signed by Y on date Z".
- Approval fatigue is addressed structurally rather than by asking humans to be
  more diligent.
- Revocation is a first-class, recorded act, so withdrawing trust is as
  auditable as granting it.

### Negative

- A policy is a broader grant than a single approval, and a poorly scoped policy
  authorises more than intended. The blast radius of a bad policy decision is
  larger than that of a bad single decision.
- Two authorisation paths now exist (direct decision, policy-cited decision),
  which the UI and the record must distinguish clearly or the audit trail
  becomes ambiguous.
- Policies accumulate. Without visibility they become invisible standing grants
  that nobody remembers approving.

### Mitigation

- Scope is mandatory and bounded; open-ended policies are rejected at
  construction, not at review time.
- Production promotion is explicitly non-delegable, so the highest-consequence
  action retains a per-event gate regardless of policy.
- Active policies are surfaced on the subject they govern (product governance
  panel), not buried in a settings screen, so a standing grant is visible
  wherever its effects are.
- Every action shows its authorising decision inline, so a policy-authorised
  action is never mistaken for one a human approved individually.

## Related

- ADR 0012 — Immutable Artifact Promotion (human gates only where required:
  production; production gate is not delegable)
- ADR 0013 — Human Gates Are Durable Workflow States (gate entry terminates
  execution; decisions are durable and signed)
- ADR 0018 — Per-Product Git Credentials
- AGENTS.md §13b — Where Human Gates Belong
- Checkpoint 006 — Product Registry and Onboarding
