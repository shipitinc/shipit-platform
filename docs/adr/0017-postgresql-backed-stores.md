# ADR 0017: PostgreSQL-Backed Stores and Read-Only Control-Plane Endpoints

## Status
Accepted

## Context
ADR 0016 built a durable persistent scheduler with claim-CAS job queueing on a
file-backed store. Restart was proven against `FileJson*` stores, which cannot
hold production state and were never shared across replicas. ADR 0002 chose
Serverpod for the control plane, and ADR 0004 fixed Postgres as the platform
store — but nothing had yet wired the platform's store contracts to Postgres or
exposed durable state to the control-plane client. This ADR closes that gap:

- **One durability source of truth.** Every store contract in
  `workflow_store`, `scheduler`, `worker_runtime`, and `execution_coordinator`
  must be satisfied by real Postgres-backed implementations, so the whole
  platform can restart from only its durable rows.
- **Contract-first storage.** The store contracts are the API. Postgres
  implementations live behind them and are proven by the `store_contract_tests`
  contract suite that the in-memory and file implementations already pass.
- **Processes must survive asymmetric failure.** A scheduler can claim a job
  and die before dispatching; a worker can be mid-execution when the platform
  restarts; a human decision can be requested but never answered. Restart
  reconciles each durable boundary exactly once — no duplicate jobs, no
  double-dispatches, no lost decisions.
- **Endpoints must never move workflow state.** `WorkItem.state` is owned by
  the state machine in `workflow_engine`. A control-plane API that mutated the
  state directly would bypass transition validation and QA gates. The only
  request-side durable write is resolving a demanded human decision, which
  runs through `DurableWorkflowEngine.resolveHumanDecision` and its validated
  `Transition` routing.

## Decision
**Implement five PostgreSQL-backed store classes in `apps/server`
(`PostgresWorkflowStore`, `PostgresJobStore`, `PostgresWorkerStore`,
`PostgresWorkerRegistrationStore`, `PostgresExecutionStore`) that satisfy the
existing store contracts, statelessly over a Serverpod `Session`. Drive them
exclusively through transactional `DurableWorkflowEngine` /
`JobStore`+`JobQueue` / `WorkerStore` / `ExecutionStore` APIs, and expose
durable state to clients only through thin read-only Serverpod endpoints plus
one decision-resolution endpoint.**

- **Stores are stateless; sessions carry transactions.** A store instance is a
  plain object over a `PersistenceDatabase` (a thin wrapper that yields the
  raw `Session.db`). All multi-write flows run in a single eager transaction
  via the store interface's `inTransaction`, so a process crash mid-write
  rolls back cleanly. Nested structures persist as JSON text columns
  (`*Json`); `timestamp without time zone` persists UTC wall-clock time, and a
  shared `decodeUtc` helper re-reads it as UTC. Serialization stays
  `json_serializable` at the domain layer — Serverpod models are never used.
- **Write rules mirror the contracts.** `saveWorkItem` and job save are
  compare-and-swap guarded `UPDATE`/`INSERT ... ON CONFLICT DO NOTHING`;
  re-checked `expectedVersion` rejects stale writers with
  `ConcurrentModificationException` / `ConcurrentJobModificationException`.
  A partial unique index `job_active_dedupe_unique`
  (`job(dedupeKey) WHERE state IN ('queued','claimed','running',
  'retryWaiting')`) enforces ADR 0016's dedupe key at the database, so
  duplicate active jobs are impossible even under multi-replica races; the
  terminal job releases its slot for a new window. Claims are exclusive via an
  in-transaction `UPDATE ... WHERE jobId=@id AND state='queued'`.
- **Endpoints observe, never set.** `WorkflowEndpoints`, `SchedulerEndpoints`,
  `WorkerEndpoints`, and `ExecutionEndpoints` are read-only inspectors that
  return domain `.toJson()` shapes. `WorkflowEndpoints.resolveDecision` is the
  single behavioral write and delegates to the engine. Endpoint failures are
  structured-logged (`StructuredLogger` via `session.log`) and re-thrown;
  Serverpod has no generic exception type, so the server never fabricates
  HTTP semantics for domain errors.
- **Persistence contracts are the durable boundary.** No PostgreSQL type,
  Serverpod model, or endpoint lives in the domain packages; `platform_contracts`
  and the store contracts keep `AgentResult`, `HumanDecision`, `QAEvidence`
  semantics provider-neutral.

## Consequences
- The entire platform — workflow, scheduler, workers, execution coordinator,
  human decisions — can be reconstructed from Postgres alone, proven by E2E
  crash/restart tests that discard all in-memory state and re-hydrate fresh
  objects (workflow resume, claim-crash requeue-with-exactly-one-dispatch,
  lease-protected running workers, adopted finished executions, durable
  blocking decisions with idempotent resolution, idempotent transition replay).
- Endpoints cannot accidentally bypass workflow policy: state changes reach
  the DB only through validated `Transition`s.
- The concurrency suites prove single-writer semantics (`pool max 10`, serial
  `-j 1` integration runs) — a stale CAS, a claim race, a dedupe race, and a
  double-resolve each converge exactly once.
- Integration tests run serially against one schema; `test:control-plane`
  forces `dart test -j 1` because a shared-PG TRUNCATE cleanup races any
  parallel runner.
- Still out of scope: HTTP/gRPC dispatch transport, distributed/remote
  workers beyond Postgres-backed stores, UI wiring, multi-tenant auth on the
  endpoints. The `job_active_dedupe_unique` index is appended by migration
  (Serverpod warns it is "missing" until the index is generated natively).