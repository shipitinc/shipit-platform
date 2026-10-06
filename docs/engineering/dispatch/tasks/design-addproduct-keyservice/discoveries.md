# Durable discoveries — lane `design-addproduct-keyservice`

Classified per `docs/engineering/LEARNING_POLICY.md` § Classification categories. Each carries
exactly one category, a product-specific/reusable judgement, and the authority level required to
persist it.

**Authority note.** This lane's `OWNED_PATHS` is
`docs/engineering/dispatch/tasks/design-addproduct-keyservice/**`. `WORK_STATE.md`, `.decisions/**`
and `docs/engineering/dispatch/LANES.md` are Manager-owned, so I have **persisted nothing outside my
owned paths**. Findings marked below as *Manager action* are reported, not written into the ledger.
`PROJECT_FACT` and `DESIGN_DISCOVERY` are automatic-persist per the policy; `ARCHITECTURE_DISCOVERY`
and `CONTRADICTION` require a human decision and are escalated, not persisted by me.

---

## D-1 — The ledger's "zero deploy-key infrastructure" VERIFIED FACT is false

- **Category**: `CONTRADICTION`
- **Product-specific**: yes
- **Authority**: human decision / Manager (governance + architecture)
- **Evidence**: `WORK_STATE.md:329-330` and `DEC-b869ec24`'s context claim "no deploy-key
  infrastructure exists server-side", citing a grep for `deployKey`/`deploy_key`. Re-verified at
  `77c19f1`:

  ```bash
  grep -rn "RepositoryCredential\|recordGeneratedCredential\|product_credential" \
      apps/server/lib packages --include="*.dart"
  ```

  returns `RepositoryCredential` (`repository_credential.dart:36`), `CredentialStatus`/`HostKeyStatus`
  (`credential_status.dart:6,41`), the `product_credential` table (`repository_credential.spy.yaml:2`,
  present in 12 `definition.sql` migrations), `RepositoryCredentialView`
  (`repository_credential_view.yaml`), four store methods (`product_registry_store.dart:39-55`), the
  Postgres implementation (`postgres_product_registry_store.dart:173-320`), the mapper
  (`ui_view_mappers.dart:169`), and **six engine methods** — `recordGeneratedCredential` (912),
  `confirmHostKey` (974), `recordCredentialCheck` (1020), `revokeCredential` (1058),
  `rotateCredential` (1084), `requireUsableCredential` (1138).

- **Why it matters**: the wrong grep produced a *false architectural conclusion* ("this is net-new
  capability"), which would have led a future lane to invent a parallel credential abstraction beside
  `RepositoryCredential` — the exact thing dispatch R4 calls a review blocker. The naming is
  `credential`, not `deploy_key`.
- **Reusable lesson** (framework candidate): *before concluding "capability X does not exist", search
  for the domain's own vocabulary, not the requester's vocabulary.* A grep built from the words in a
  feature request is a grep that will miss the implementation.
- **Persistence**: reported to the Manager for `WORK_STATE.md` + a superseding decision note. **I did
  not edit them** (outside `OWNED_PATHS`).

## D-2 — The exact greps that would have prevented D-1

- **Category**: `PROJECT_FACT` (executable knowledge)
- **Authority**: automatic (evidence-backed)
- **Content**: the surface a future session must not re-derive:

  | Question | Command |
  |---|---|
  | Does credential infrastructure exist? | `grep -rn "RepositoryCredential\|recordGeneratedCredential\|product_credential" apps/server/lib packages --include="*.dart"` |
  | Does any endpoint expose a credential view? | `grep -c "RepositoryCredentialView" apps/server/lib/src/endpoints/*.dart` → **0** for all 11 files |
  | Is there SSH host-key verification? | `grep -rn "SSH_AUTH_SOCK\|known_hosts\|ssh-keyscan\|StrictHostKeyChecking\|IdentityFile" apps packages --include="*.dart" --include="*.yaml"` → **no match** |
  | Is the control plane authenticated? | `sed -n '71,72p' apps/server/lib/server.dart` → declares no authentication services |
  | Are compose bindings loopback-pinned? | `grep -rn "127.0.0.1:" docker/*.yaml apps/server/docker-compose.yaml` → **no match** |

- **Preferring executable knowledge**: per `LEARNING_POLICY.md` § "Prefer executable knowledge", these
  five commands are the durable form of this finding. Each returns a different answer than the
  corresponding claim in the ledger.

## D-3 — `HostKeyStatus` has no runtime enforcer; the git transport passes no environment

- **Category**: `ARCHITECTURE_DISCOVERY`
- **Authority**: human decision (architecture)
- **Evidence**:
  - `packages/worker_runtime/lib/src/workspace/git_workspace_inspector.dart:106-112` —
    `Future<String> _capture(List<String> args) => Process.run(git, args)`, with **no `environment:`
    argument**. Neither a credential nor a host-key policy can reach the transport today.
  - A repo-wide grep for `SSH_AUTH_SOCK|known_hosts|ssh-keyscan|StrictHostKeyChecking|IdentityFile`
    across `apps` and `packages` returns **no match**.
- **Why it matters**: the domain's most careful security property — a host that is not `confirmed`
  cannot be connected to (`HostKeyStatus.permitsConnection`) — is currently **decorative with respect
  to runtime**. Any design that assumes "the engine refuses unconfirmed hosts" is assuming an
  enforcement that does not exist. This affects any design that touches the credential path, not only
  mine.
- **Escalated**: to the Manager as a named prerequisite for the `implement-addproduct` lane.

## D-4 — Registering a product cannot be gated on a credential, because minting requires the product

- **Category**: `ARCHITECTURE_DISCOVERY`
- **Authority**: human decision (architecture + product)
- **Evidence**: `recordGeneratedCredential` (`engine:912-967`) calls
  `readRepositoryReference(repositoryId)` and `_ensureOwned(productId, repo.productId)` at `:924-925`;
  `addRepositoryReference` (`:150-174`) requires the product to exist; `createProduct` (`:43-63`)
  hardcodes `state: ProductState.registered`. So the enforced order is
  `createProduct → addRepositoryReference → recordGeneratedCredential → confirmHostKey →
  recordCredentialCheck`.
- **Why it matters**: human point 2b ("Register product is dependent on this key generation and trust
  of this host") is therefore **circular** against the domain — the gate depends on an artifact that
  the gated action creates. This is the same structural defect class as the current
  `canRegister == false`, arriving through a different route. Any future lane designing "generate on
  URL input, then gate registration on the key" will hit this and must not paper over it.
- **Not in the dispatch brief**; found by reading the engine. Surfaced as **OPEN-D4-2** with three
  options and a recommendation. Escalated, not decided.

## D-5 — `RepositoryCredential.copyWith` cannot change key material or identity

- **Category**: `PROJECT_FACT`
- **Authority**: automatic
- **Evidence**: `repository_credential.dart:137-172` — `copyWith` accepts only `status`,
  `lastVerifiedAt`, `lastVerifiedBy`, `lastFailureReason`, `hostKeyStatus`, `host`, `hostKeyFingerprint`,
  `hostConfirmedAt`, `hostConfirmedBy`, `revokedAt`, `revokedReason`, `version`. It has no parameter
  for `credentialId`, `productId`, `repositoryId`, `referenceName`, `publicKey`, `fingerprint`,
  `algorithm` or `supersedesCredentialId`, and `props` (`:180-202`) includes them all.
- **Why it matters**: this immutability is what makes silent key rotation **structurally** impossible
  rather than merely discouraged, and it means the substrate of a stored private key cannot be changed
  for an existing credential without rotation. That is a design constraint a future lane would
  otherwise have to rediscover — and it is the reason `DEK`-style repointing is safe by default.

## D-6 — ADR 0018 and `AGENTS.md §13a` do not exist in this repository

- **Category**: `CONTRADICTION`
- **Authority**: human decision / Manager (governance)
- **Evidence**: `ls docs/engineering/adr/` → `0001-framework-distribution-and-versioning.md`,
  `0002-dart-mason-git-framework-driver.md`, `0003-product-generic-orchestrator-skill.md`. `AGENTS.md`
  sections are `Inherited invariants`, `Orchestration`, `Product-specific policy`,
  `Framework provenance` — no §13. Cited in nine places: `repository_credential.dart:10`,
  `credential_status.dart:1,36`, `product_registry_store.dart:7,35`,
  `repository_credential.spy.yaml:4`, `repository_credential_view.yaml:1`,
  `product_registry_engine.dart:898`.
- **Why it matters**: the credential model I was told to design onto is governed by a document that
  cannot be read. Any lane touching credentials will either cite ADR 0018 without having read it, or
  — worse — invent its content and present it as authoritative. I recorded **ten** substitute
  assumptions (`design-revision.md` § R.21) instead, each with the code that evidences it, so a
  reviewer can falsify any of them.
- **Reusable lesson**: *a code comment citing an ADR id is not evidence the ADR exists. Verify the
  citation resolves before reasoning from it.*
- **Escalated**: correcting the dangling citations is a Manager action (outside my `OWNED_PATHS`).

## D-7 — The loopback-pinning mitigation is not implemented

- **Category**: `PROJECT_FACT`
- **Authority**: automatic
- **Evidence**: `grep -rn "127.0.0.1:" docker/*.yaml apps/server/docker-compose.yaml` → **no match**.
  `docker/compose.qa.yaml:17,56,74` publish `5432:5432`, `8080:8080`, `8081:8081` unqualified, which
  Docker resolves to `0.0.0.0`.
- **Why it matters**: `DEC-570bb640` (RESOLVED, OPTION_B) relies on the "local only" premise being
  enforced, and names the pinning as a follow-up action. The decision's *accepted risk is therefore
  currently live on any shared network*. A design that cites `570bb640` as though the scope were
  enforced would be citing an intention, not a control. Recorded as a verified negative so no lane
  repeats the assumption.
- **Note**: read-only file inspection only. **No Docker or Compose command was executed by this lane.**

## D-8 — `RepositoryCredentialView` carries no `publicKey`

- **Category**: `PROJECT_FACT`
- **Authority**: automatic
- **Evidence**: `repository_credential_view.yaml:7-26` lists `credentialId`, `repositoryId`,
  `referenceName`, `fingerprint`, `algorithm`, `status`, `hostKeyStatus`, `host`,
  `canReachRepository`, `lastVerifiedAt`, `lastVerifiedBy`, `lastFailureReason`, `hostConfirmedAt`,
  `hostConfirmedBy`. **No `publicKey`.**
- **Why it matters**: the existing credential wire type cannot express a key-export response, so the
  mint endpoint needs a dedicated type. The upside is that the public half can stay **out** of the
  `ProductDetailView` read surface entirely — a better default than widening an existing view.
  Also: the type exposes `referenceName` to clients, which under server-side storage becomes a
  path/ARN disclosure (gap `G-7`).

## D-9 — The access-check control has zero producers of its success value

- **Category**: `DESIGN_DISCOVERY`
- **Authority**: automatic
- **Evidence**: `grep -rn "canRegister\|canGenerateKey\|AccessStatus\." apps/control_plane/lib` shows
  `AccessStatus.verified` appearing only in **predicates and labels** (`:235,563,609,659,731,884,1059,1105`),
  never as an assignment. The only `accessStatus:` assignment is `:118 → notChecked`. So
  `canRegister` (`:233-236`), which requires `verified`, is constantly `false`.
  Separately, `canGenerateKey` (`:230`) has **zero** call sites, and `deployKey` is assigned only at
  `:117` from inside `_buildKeyBox`, which renders only `if (state.deployKey != null)` — a bootstrap
  deadlock.
- **Why it matters**: finding B5 is not "the check needs wiring"; it is **two** independent defects —
  an unreachable success value *and* a deadlock that prevents the key panel from ever rendering. A
  correction lane fixing only the first would still see no key panel.

---

## Not persisted

| Finding | Why not |
|---|---|
| The a11y contrast figures (4.23:1 / 6.74:1 / 6.10:1) | Inherited from `design-register-button/report.md:71-76`; **I did not re-measure them**. Reported as inherited in the revision, not asserted as mine |
| `flutter analyze` / `dart analyze` / build / test results | Not run. Reported as `NOT_RUN`, and no feasibility gate is claimed from them |
| Whether a real SSH transport accepts the generated key | Requires a running stack; `UNVERIFIED` with the command named. **No Docker command was run** |