# Report — impl-client-addproduct-keyflow

Wire Add Product to the real key service so Register becomes pressable.

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: impl-client-addproduct-keyflow
TASK_TYPE: implement
RESULT: IMPLEMENTED
```

---

## Provenance

| | |
|---|---|
| Repository | `/Users/alkebut/air/shipit-platform` |
| Worktree | `/private/tmp/shipit-client-keyflow` |
| Branch | `impl/client-addproduct-keyflow` |
| BASE_SHA | `c110aa243f41d0bedf7dcc6de72b7462173461f6` |
| HEAD_SHA | `2f6b78dfd721598b8ea60ae29ad70194c53a92e1` |
| Commits | 3 — `3ac2c3e` generated client · `705b64f` client wiring · `2f6b78d` tests |
| Pushed / merged | **No.** Nothing pushed, nothing merged, `main` untouched. |

Pre-flight verified before writing anything: `git branch --show-current` →
`impl/client-addproduct-keyflow`, `git rev-parse HEAD` → `c110aa2`, tree clean.

---

## 1. Proof `AccessStatus.verified` is now WRITTEN

`apps/control_plane/lib/features/products/add_product_page.dart:187-197`:

```dart
      emit(
        state.copyWith(
          isCheckingAccess: false,
          accessStatus: verification.isVerified
              ? AccessStatus.verified
              : AccessStatus.failed,
          accessFailureReason: verification.isVerified
              ? null
              : verification.failureReason,
        ),
      );
```

**`add_product_page.dart:191` — `? AccessStatus.verified` — is the write.**

`AccessStatus.checking` is written too, at `add_product_page.dart:130`, which the
UI's "Checking access…" branch had always read and never seen.

Verification of the "written in ZERO" claim at base, and that it is now written:

```
$ git grep -n 'AccessStatus\.\(verified\|checking\)$' c110aa2 -- apps/control_plane/lib/features/products/add_product_page.dart
c110aa2:...:542:      case AccessStatus.verified:                 # read (status label)
c110aa2:...:551:                      state.accessStatus == AccessStatus.verified   # read
... every occurrence a comparison, a switch case, or a getter — 0 writes

$ grep -n 'AccessStatus.verified' apps/control_plane/lib/features/products/add_product_page.dart
191:              ? AccessStatus.verified      # the write
```

The enum and all nine pre-existing read sites are unchanged — `canRegister`, the
`Verified`/`Access failed` status labels, both step-2 `isDone` flags, both
`Check again`/`Check access` labels, and `_registerButtonSubtext`. `canRegister`
itself is byte-identical to the base version; it was made *reachable*, not weakened:

```dart
  bool get canRegister =>
      deployKey != null &&
      accessStatus == AccessStatus.verified &&
      !isRegistering;
```

**Mutation proof that the guard bites.** Temporarily replacing the write with
`AccessStatus.failed` fails 6 of the 20 new tests, including the two that name it:

```
[E] canRegister — the gate that was permanently closed is true once verifyAccess has succeeded
[E] Check access calls generate, then verifyAccess, and the successful verification is what writes AccessStatus.verified
[E] Register leaves a credential row attached to the credential it verified, and creates no product without one
[E] Register refuses to register when the verified credential is not attached
[E] Register refuses to register a credential the durable record says is not verified
[E] no key material reaches the client across the whole Check-access and Register conversation
```

Reverted; the committed HEAD is the version above.

---

## 2. The mock generator is deleted

`_generateMockKeyPair` and `_computeFingerprint` are gone, and with them
`dart:math`, `dart:typed_data` and `dart:convert` — none of which has any other
use in this file.

**Before, at `c110aa2`:**

```
$ git grep -n "_generateMockKeyPair\|Random\.secure" c110aa2 -- apps/control_plane/lib
c110aa2:apps/control_plane/lib/features/products/add_product_page.dart:113:      final keyPair = _generateMockKeyPair(state.productName);
c110aa2:apps/control_plane/lib/features/products/add_product_page.dart:126:  DeployKeyPair _generateMockKeyPair(String productName) {
c110aa2:apps/control_plane/lib/features/products/add_product_page.dart:127:    final random = Random.secure();
```

**After, at HEAD:**

```
$ grep -rn "_generateMockKeyPair\|_computeFingerprint\|Random\.secure\|ed25519_edwards\|PointedData" \
      apps/control_plane/lib packages/control_plane_client/lib
exit=1   (zero matches)

$ grep -rn "import 'dart:math'" apps/control_plane/lib
exit=1   (zero matches)

$ grep -rn "ssh-ed25519" apps/control_plane/lib
apps/control_plane/lib/data/control_plane_repository.dart:1839:  /// The `ssh-ed25519 AAAA… shipit+<repositoryId>` line the operator installs
```

The single surviving `ssh-ed25519` occurrence is a doc comment describing the
line the **server** mints. There is no client-side key construction of any kind:
no randomness source, no base64 key formatting, no fingerprint computation.

This is also an **executable** check, not a note in a commit:
`test/blocs/add_product_bloc_test.dart` scans `apps/control_plane/lib` for
`_generateMockKeyPair`, `_computeFingerprint`, `Random.secure`,
`ssh-ed25519 $base64`, `ed25519_edwards`, `PointedData` and
`import 'dart:math'`, and fails naming the file and token. Planted `Random.secure`
into `products_page.dart` as a probe and it reported exactly that:

```
Actual: ['lib/features/products/products_page.dart: Random.secure']
```

---

## 3. `packages/control_plane_client` exposes the credential endpoints

**Before** — the prior reviewer's finding was correct. The generated client
predated the server half:

```
$ rg -c "credentialEndpoints" packages/control_plane_client/
exit=1   (zero matches, pre-regeneration)
```

**`serverpod generate` was run from this worktree** (after `dart pub get` at repo
root). **After**, `packages/control_plane_client/lib/src/protocol/client.dart`:

```dart
 73: class EndpointCredentialEndpoints extends _i1.EndpointRef {
 74:   EndpointCredentialEndpoints(_i1.EndpointCaller caller) : super(caller);
 77:   String get name => 'credentialEndpoints';

 88:   _i2.Future<Map<String, dynamic>> generate({
 89:     required String productId,
 90:     required String repositoryId,
 91:     String? credentialId,
 92:   }) => caller.callServerEndpoint<Map<String, dynamic>>(
 93:     'credentialEndpoints',
 94:     'generate', { 'productId': productId, 'repositoryId': repositoryId,
 97:       'credentialId': credentialId, },
100:   );

122:   _i2.Future<Map<String, dynamic>> verifyAccess({
123:     required String productId,
124:     required String repositoryId,
125:     required String hostKeyFingerprint,
126:     required String confirmedBy,
127:     String? checkedBy,
128:   }) => caller.callServerEndpoint<Map<String, dynamic>>(
129:     'credentialEndpoints',
130:     'verifyAccess', { … },
138:   );

1180:    credentialEndpoints = EndpointCredentialEndpoints(this);
1194:  late final EndpointCredentialEndpoints credentialEndpoints;
1220:    'credentialEndpoints': credentialEndpoints,      // endpointRefLookup
```

The generated signatures match the server at
`apps/server/lib/src/endpoints/credential_endpoints.dart:125-129` and `:184-191`
exactly — verified against the source, not the dispatch summary.

The regeneration also picked up unrelated drift that proves the client really was
stale: `productRegistryEndpoints.createProduct`'s `manifestJson` changed from
`required String` to `String?`, matching the server's
`product_registry_endpoints.dart:449`. That matters for this lane — the Add
Product flow calls `createProduct` with `manifestJson: '{}'`, and the old client
signature was simply out of date.

### `serverpod generate` exits 1 — a pre-existing server defect, NOT fixed here

```
$ dart run serverpod_cli generate            # from apps/server
✗ Generating code (61.6s)
ERROR: Found 1 issue.
Error on line 105, column 18 of
package:control_plane_server/src/endpoints/credential_endpoints.dart:
Return type must be a Future or a Stream.
 105 │   SecretProvider recordCustodyPrecondition(Session session) {
```

`CredentialEndpoints.recordCustodyPrecondition` is a **public** method on an
Endpoint returning `SecretProvider`. Serverpod requires every public endpoint
member to return a `Future` or a `Stream`, so the generator refuses the file.

**This is in `apps/server/**`, which is PROHIBITED to this lane. Not fixed,
not worked around.** Reported as **BLOCKER-1** below.

What it does and does not affect, verified rather than assumed:

* The **client output is written before the error is reported.** Two consecutive
  runs produced **byte-identical** `client.dart` — the symbols quoted above are
  the stable output, not a half-written artefact.
* The **server-side generated output is byte-identical to `c110aa2`.** Hash of
  every tracked file under `apps/server` was `dd1483b0055…` before generation and
  `dd1483b0055…` after, and `git diff --name-only c110aa2 HEAD -- apps/server`
  returns **0 files**. No prohibited file was modified.
* `apps/server/lib/src/generated/endpoints.dart` already listed
  `credentialEndpoints` at `c110aa2`, so the server side was current and only the
  client package was stale.

---

## 4. End-to-end flow, and what the human must do in GitHub

### What the app now does, step by step

1. **Operator types** `PRODUCT NAME` (`SHIP IT Platform`), `REPOSITORY (SSH)`
   (`git@github.com:shipit/shipit-platform.git`), `REVISION OR BRANCH`.
   Register stays disabled with **"Product name is required"**.
2. **Operator presses `Check access`.** `AddProductBloc._onCheckAccessRequested`
   runs, in order:
   1. `_ensureProductAndRepository('ship-it-platform')` — `createProduct` then
      `addRepositoryReference`. Both are server-side upserts
      (`ON CONFLICT DO UPDATE`), so this is idempotent.
      **Forced by the server:** `CredentialKeyService.generate` calls
      `engine.resolveRepository(productId, repositoryId)` *before* minting
      (`credential_key_service.dart:242`), so the product and its repository
      reference must exist or the mint is refused. They cannot wait for Register,
      because the human needs the public key before Register is pressable.
   2. `credentialEndpoints.generate(productId, repositoryId)` — the **server** mints
      a real ed25519 keypair, hands the private half to the secret provider, and
      writes the durable credential row at status `generated`. The client stores
      the public half, fingerprint, algorithm and `credentialId`. Nothing else
      comes back; there is no field in `MintedCredential` that could hold the
      private half.
   3. `_HostKeyAttestation` panel appears showing the operator-asserted host-key
      fingerprint and confirmer read from deployment configuration.
   4. `credentialEndpoints.verifyAccess(productId, repositoryId,
      hostKeyFingerprint, confirmedBy)` — the server obtains the host key itself,
      refuses to clone unless the fingerprint it computes equals the supplied one,
      then runs a **real `git clone`** and records the result.
   5. `AccessStatus.verified` is written **only** when the clone completed and the
      scratch tree holding the identity file is confirmed gone.
3. **Operator installs the key in GitHub** (below).
4. **Operator presses `Check again`** if needed. It **re-verifies without
   re-minting**: `recordGeneratedCredential` is insert-only and refuses a second
   active credential (`product_registry_engine.dart:965-972`), so a second mint
   would fail server-side. Covered by a test.
5. **Register becomes pressable.** `Register product` re-ensures the product and
   repository, **reads the product detail back**, and refuses unless the credential
   it verified is attached *and* its durable status is `verified`. Only then does
   it navigate to the product detail screen. This is the fix for "Register
   discarded the key": the old code stopped at `addRepositoryReference` and left a
   product that could never reach its repository.

### Exactly what the human must do in the GitHub UI

1. On the Add Product page, press **`Copy public key`**. It copies one line:
   `ssh-ed25519 AAAAC3… shipit+ship-it-platform`.
2. In GitHub, open the repository →
   **`Settings` → `Deploy keys` → `Add deploy key`**.
   * **Title** — anything identifying, e.g. `shipit-platform`.
   * **Key** — paste the copied line.
   * **`Allow write access`** — **tick it.** The panel's existing copy already says
     *"with write access"*; ShipIt pushes and merges on its own. A read-only deploy
     key will clone and then fail to push, and the product will never govern.
   * *(Optional but recommended)* tick **"Allow someone to override this key when
     they add a new one"** — otherwise a later GitHub-generated key of the same
     title would break ShipIt's access.
3. Confirm the host fingerprint. GitHub publishes its SSH host key fingerprints at
   **`https://api.github.com/meta`** (`.ssh_key_fingerprints`). Compare them with
   the fingerprint the Add Product panel shows. They come from deployment
   configuration — see below — **not** from ShipIt, which is finding M-5.
4. Back in ShipIt, press **`Check again`**. A real clone runs. On success the key
   box reads **`Verified`**, step 2 ticks, and **Register product** becomes
   pressable.
5. Press **`Register product`**.

### Configuring the two operator-asserted values

`hostKeyFingerprint` and `confirmedBy` are **required** by `verifyAccess` and are
**operator assertions the server cannot authenticate** (M-5, open). They come
from configuration and are **never hardcoded**:

* **Build-time (works today, no file outside this lane's ownership changes):**
  ```
  --dart-define=SHIPIT_HOST_KEY_FINGERPRINT=SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU \
  --dart-define=SHIPIT_OPERATOR_NAME="Dana Okafor"
  ```
  e.g. `cd apps/control_plane && flutter run -d web-server --web-port 8081 \
  --dart-define=SHIPIT_HOST_KEY_FINGERPRINT=SHA256:… --dart-define=SHIPIT_OPERATOR_NAME="…"`.
* **Runtime (preferred for deploys):** `window.SHIPIT_CONFIG.HOST_KEY_FINGERPRINT`
  and `window.SHIPIT_CONFIG.OPERATOR_NAME`. **See BLOCKER-3** — the template that
  publishes these keys is `docker/config.js.template`, outside this lane's
  ownership, so until it is updated the runtime lookup returns `null` and the
  `--dart-define` value is used.

When neither is configured, **minting still works and verification does not run**:
the operator gets an installable public key, the panel states which values are
missing, and `canRegister` stays `false`. No fingerprint is invented — a
fingerprint the deployment never supplied is exactly the silent default ADR 0018
refuses. Covered by a test.

### What the client does NOT do with the confirmed fingerprint

It is passed through verbatim and adds no meaning to it. The panel says so in the
product's own words: *"Compare this against the fingerprints your git host
publishes, then install the key. ShipIt checks that the host presents the same key
and refuses to clone when it does not — but it asks you for it, it does not look
it up."* A green **Verified** therefore does not read as "the platform checked
GitHub's identity", which is the misunderstanding M-5 describes.

---

## 5. Blockers and things found — reported, not worked around

### BLOCKER-1 — `serverpod generate` exits 1 on a defect in `apps/server/**` (PROHIBITED)

`credential_endpoints.dart:105` — `SecretProvider recordCustodyPrecondition(Session)`
is a public Endpoint member whose return type is neither `Future` nor `Stream`, so
Serverpod's generator refuses the file. Fixing it requires touching
`apps/server/**`, which is PROHIBITED to this lane and is already merged and
reviewed.

* Does **not** block this lane: the client regeneration lands, is deterministic,
  and changed no server-side generated byte.
* **Does** mean `serverpod generate` currently exits non-zero for the whole
  repository. Every future lane that regenerates will hit it, and any CI step that
  gates on a zero exit will fail. Owner: the `apps/server` lane. Note the method
  is documented as "startup wiring calls it with any session, or simply constructs
  the endpoint" — making it private, or returning `Future<SecretProvider>`, are
  both one-line fixes, **neither of which is mine to make**.

### BLOCKER-2 — Register cannot itself mint the credential; the product row is written before Register

The dispatch's test 3 says *"Register creates a credential row referencing the
generated credential."* That is **not achievable**, and the reason is structural:

* `CredentialEndpoints.generate` is the **only** client-reachable endpoint that
  writes a credential row. It calls `engine.recordGeneratedCredential`
  (`credential_key_service.dart:277`) → `saveProductCredential`.
* `generate` refuses to run unless the product and its repository reference already
  exist (`resolveRepository` first, `credential_key_service.dart:242`).
* The human must install the public key **before** pressing Register, and the
  public key only exists **after** `generate`.

So the credential row is written at `generate`, necessarily before Register.
**What Register now guarantees** — which is the dispatch's own wording in
REQUIREMENT 4, *"Register must leave a credential row that points at the generated
one"* — is that it reads the detail back and **refuses** unless the row it proved
is attached and `verified`, rather than assuming. Tested both ways: the happy path
leaves a row whose `credentialId` equals the minted one, and a cleared or
`failing` row stops registration with a named error.

Consequence the human should know: **the product row exists in the registry from
the moment `Check access` is first pressed**, not from `Register`. No UI sequence
was added for it because the approved design has none, and inventing one is a
design decision.

### BLOCKER-3 — `docker/config.js.template` publishes only `CONTROL_PLANE_API`

`OperatorAttestation` reads `window.SHIPIT_CONFIG.HOST_KEY_FINGERPRINT` and
`.OPERATOR_NAME`, but that template enumerates its keys and is `docker/**`, which
is **PROHIBITED** to this lane and where **the QA stack is up and must not be
disturbed**. Until its owner adds the two lines, runtime config yields `null` and
the `--dart-define` build-time path is the only working one. It works today with
no docker change, so this is a convenience gap, not a blocker — but it should not
be described as "runtime configurable" until that file is updated.

### Observation — G-7 is real, still open, and I did not touch it

`.decisions/9417f8bf-73b8-4827-9515-bdfe92e5a9d5.yaml` is `status: RESOLVED` and
records, as a **binding** follow-up owned by `design-agent`:

> Remove `referenceName` from `RepositoryCredentialView`, or replace it with a
> non-identifying handle. Under A3 the reference IS the sensitive artifact; G-7 was
> optional while the substrate was undecided and is now **required**.
> … a generated-contract change in two packages.

Observed, unchanged, as instructed:

* `RepositoryCredentialView` still carries `referenceName` (it is generated from
  `packages/product_registry`, which is **PROHIBITED** to this lane).
* `CredentialResponse.referenceName` still exists and is still read at
  `control_plane_repository.dart:108` and `:1098` — a **pre-existing** client-side
  use that predates this lane. Left exactly where it was.
* **No new client-side use was added.** `generateDeployKey` maps the response
  field-by-field into a new `MintedDeployKey` that **does not read `referenceName`
  at all**, so the Add Product flow neither displays nor holds the reference. There
  is a test asserting exactly that, and another asserting the whole
  Check-access → Register conversation carries no key material.

So G-7's removal is still required, still unowned-by-me, and this lane narrows
nothing and closes nothing — it only refuses to widen the exposure.

### Observation — the generated client was stale in a second, load-bearing way

`createProduct`'s `manifestJson` was `required String` in the client and `String?`
on the server. The Add Product flow calls `createProduct` at all, so a client that
had merely been given the credential endpoints would still have been out of step
with the server. Fixed by the regeneration. This is also the second independent
piece of evidence that the client package had not been regenerated since before
the server half landed (H-1).

### Observation — existing `errorMessage` behaviour interacts badly with a failed check

`_AddProductView` replaces the **entire page** with `DesignErrorState` whenever
`errorMessage != null`. A verification failure that used that surface would destroy
the form the operator was standing on. Rather than change the approved error
surface, failures are routed by what the operator needs to see:

* failure **before** a key exists → page-level `errorMessage` (there is no key box
  to put it in);
* failure **with** a key → `accessFailureReason`, rendered inside the existing key
  box, beneath the existing *"Access check failed. Ensure the key is installed with
  write access."* line, plus the server's own `failureReason` — which is documented
  server-side as safe to show an operator (`repository_access_verifier.dart:33-36`:
  git/ssh's diagnostic with the scratch path replaced and truncated, never key
  material).

Both branches are tested.

### Observation — a `Revoked`-by-status hole Register now closes

`canRegister` reads client state, so it cannot notice that the durable credential
was revoked between the check and the press. Register's read-back catches it: a
`failing` or `revoked` row refuses registration with a named error. This is why
Register verifies rather than trusts.

---

## Gates — run verbatim against HEAD `2f6b78d`

| Gate | Command | Result |
|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` (repo root) | **pass** — `Formatted 657 files (0 changed)`, exit 0 |
| analyze | `cd apps/control_plane && flutter analyze` | **pass** — `No issues found!`, exit 0 |
| tests | `cd apps/control_plane && flutter test` | **pass** — `266: All tests passed!`, exit 0, **0** `[E]` |
| runtime | — | **n/a** — no browser/QA-stack interaction; the QA stack was not touched |

**Test count: 266, not the briefed +190.** The real baseline measured on
`c110aa2` before any edit was **246**; this lane adds **20**, giving 266. Every
pre-existing test still passes and **nothing was weakened, skipped, `@Ignore`d,
filtered or deleted** — `git diff --numstat` shows deletions only in
`add_product_page.dart` (the mock and the replaced logic), `runtime_config_web.dart`
(the `readControlPlaneApi` body, now a delegation) and `client.dart` (one stale
signature line). `test/helpers/unimplemented_repository_apis.dart` is **+19 / −0**.

`make test-integration` was **not** run, per instruction. **Zero Docker or Compose
commands were issued in this lane**, mutating or otherwise; compose was never even
read as a command. No test database was created, so no teardown was needed.

---

## The 20 new tests

`apps/control_plane/test/blocs/add_product_bloc_test.dart`, driven through a fake
that models the two server facts the client depends on — `generate` requires the
product and repository reference to exist, and a credential is insert-only — so a
client regression cannot pass unnoticed.

**Requirement 1 — the gate:**
1. false before anything is minted
2. **false after a mint while access is unproven** — the middle case, the regression guard
3. false while a verification is in flight
4. true once `verifyAccess` has succeeded
5. false when the deployment supplied no host-key confirmation, and
   `verifyDeployKeyAccess` was **never called** — nothing may be asserted to the
   server that was not configured

**Requirement 2 — the mock is gone:**
6. executable scan of `apps/control_plane/lib` for the mock and every key-generation
   token, naming file and token
7. no key-generation library imported, no algorithm named to construct

**Requirement 3 — Register persists the credential, no key material:**
8. Register leaves a credential row whose `credentialId` is the minted one, status `verified`
9. Register refuses when the row is absent (`not attached`)
10. Register refuses when the row says `failing` (`not "verified"`)
11. Register does nothing when the gate is shut
12. no key material in anything sent to the server, across the whole conversation
13. the client never reads the secret-manager reference — G-7

**Requirement 4 — a failure surfaces:**
14. a failed verification leaves `canRegister` false, shows the reason beside the key, and does not destroy the form
15. a verification the server refuses (`HostKeyNotPresented`) leaves `canRegister` false and names the failure
16. a mint that fails before a key exists reports on the page-level surface where it can be seen

**Call-order and contract:**
17. `createProduct` → `addRepositoryReference` → `generate` → `verifyAccess`, in order
18. the fingerprint and confirmer reach the server from configuration
19. the server-minted public half is stored verbatim
20. **"Check again" re-verifies without minting a second credential** (the engine refuses one)

---

## Files changed

```
 apps/control_plane/lib/data/control_plane_repository.dart         | 183 +++++
 apps/control_plane/lib/data/operator_attestation.dart             |  86 +++   (new)
 apps/control_plane/lib/data/runtime_config_stub.dart              |   7 +
 apps/control_plane/lib/data/runtime_config_web.dart               |  21 +-
 apps/control_plane/lib/features/products/add_product_page.dart    | 382 ++++--
 apps/control_plane/test/blocs/add_product_bloc_test.dart          | 814 +++++ (new)
 apps/control_plane/test/helpers/unimplemented_repository_apis.dart |  19 +
 packages/control_plane_client/lib/src/protocol/client.dart        | 102 +-
 8 files changed, 1552 insertions(+), 62 deletions(-)
```

**Ownership.** All eight paths are inside the declared `OWNED_PATHS`
(`apps/control_plane/lib/**`, `apps/control_plane/test/**`,
`packages/control_plane_client/**`).

* `PROHIBITED_PATHS` — **zero files touched.** `git diff --name-only c110aa2 HEAD`
  lists nothing under `apps/server/**`, `docker/**`, `.github/**`, `docs/adr/**`,
  `.decisions/**` or `packages/product_registry/**`. The hash of every tracked file
  under `apps/server` is byte-identical before and after `serverpod generate`.
* `READ_ONLY_PATHS` — `apps/server/lib/src/credentials/**` and
  `apps/server/lib/src/endpoints/credential_endpoints.dart` were read, never
  written. `.decisions/9417f8bf-*.yaml` and `docker/config.js.template` were read
  as text only.
* Concurrency: no other lane writes `apps/control_plane/**` or
  `packages/control_plane_client/**`; Manager holds `LANES.md` / `WORK_STATE.md` /
  `.decisions/**`. No overlap.

---

## Copies and sequence preserved

Byte-identical at HEAD and base — `git diff` shows **no changed line** containing
any of:

* `Add a product` · `NOT REGISTERED YET` (desktop and mobile)
* `PRODUCT NAME` · `REPOSITORY  (SSH)` · `REVISION OR BRANCH`, in that order
* `Product name is required` and the whole of `_registerButtonSubtext`
* `It clones over SSH. The private half stays in the secret manager — never shown, logged or stored.`
* `What happens next` and the four numbered steps, verbatim
* `WHAT SHIPIT DOES WITH THIS KEY` · `DEPLOY KEY  ·  THIS PRODUCT ONLY` ·
  `Add this key to the repository’s deploy keys with write access, then check.` ·
  `Register product`

Every deletion in `add_product_page.dart` is the mock generator or the logic it
replaced; **no UI line was removed**. What is new is strictly additive: a
`_HostKeyAttestation` panel and an optional failure-reason line inside the
existing key box, plus one `credentialId` line in each `TechnicalDetails` block.

---

## Parallel work

**SAFE_PARALLEL_WORK**
* `apps/server/**` — but only with BLOCKER-1 resolved first; see below.
* `packages/product_registry/**` — e.g. acting on G-7 (owner `design-agent`). Note
  it requires a generated-contract change in **two** packages, one of which this
  lane also owns (`packages/control_plane_client`), so **G-7 work must not run
  concurrently with this lane's HEAD** — or must wait for it and regenerate.
* `docker/**` — e.g. adding `HOST_KEY_FINGERPRINT` / `OPERATOR_NAME` to
  `config.js.template` + `entrypoint.client.sh`'s `envsubst` list, which closes
  BLOCKER-3. **Zero mutating Docker/Compose commands** until the QA run-mode
  override is retired; text edits to the template are fine.
* `docs/adr/**`, `.decisions/**`, `LANES.md`, `WORK_STATE.md` — Manager-owned
  bookkeeping, including recording BLOCKER-1/2/3 and this lane's provenance.
* CI / workflow definition (`.github/**`) — including gating on
  `serverpod generate` exit status, which **will currently fail** (BLOCKER-1).
* Any read-only review lane.

**PROHIBITED_PARALLEL_WORK**
* Any other lane writing `apps/control_plane/**` or `packages/control_plane_client/**`
  — overlapping `OWNED_PATHS`, prohibited by the AGENTS.md concurrency invariant.
* Any lane running `serverpod generate` against this branch or any branch that
  includes this one — it rewrites `packages/control_plane_client/**`, this lane's
  owned output, and will exit 1 until BLOCKER-1 is fixed.
* Any lane modifying `apps/server/lib/src/endpoints/credential_endpoints.dart` —
  PROHIBITED here and already merged/reviewed; `recordCustodyPrecondition` needs an
  owner, not a second writer.
* Anything that touches shared Docker state: `make clean`, `make qa-down`,
  `make test-env-down`, `make e2e-down`, any bare `down -v`, and any mutating
  `docker` / `docker compose` command, until QA's stopgap run-mode override is
  retired. Compose files are to be read as text, never started to find out.
* Merging, pushing, or touching `main`.

---

## Durable discoveries

| Category | Finding | Persisted as |
|---|---|---|
| `CONTRADICTION` | `apps/server/.../credential_endpoints.dart:105` — a public Endpoint method returning `SecretProvider` makes `serverpod generate` exit 1 for the **whole repository**, while `apps/server/**` is frozen and the client regeneration it gates is unowned (H-1). Client output still lands and is deterministic; server-side output is byte-identical. | **BLOCKER-1** in this report. Not written to `docs/` — `docs/**` is outside this lane's ownership. |
| `ARCHITECTURE_DISCOVERY` | `CredentialEndpoints.generate` resolves the repository reference *before* minting, so no client can mint a key before the product and its repository reference exist. Combined with "the human must install the key before Register", this **forces** the durable product row to be written during `Check access`, not during `Register`. | **BLOCKER-2**. Product/architecture shaped; a human decision, not mine. |
| `ARCHITECTURE_DISCOVERY` | `recordGeneratedCredential` is insert-only and refuses a second active credential, so any "re-check" UI must skip `generate` and go straight to `verifyAccess`. Any future rotation flow needs the `supersedesCredentialId` parameter. | Enforced by test 20 and a comment at `add_product_page.dart:145`. Product-shaped; reported. |
| `RUNTIME_DISCOVERY` | The generated client package drifts silently from the server unless `serverpod generate` is owned by someone. It was stale for **two** independent reasons — missing `credentialEndpoints`, and `createProduct.manifestJson` still `required` — both of which would have broken the flow. | The regeneration itself; the second drift is quoted in commit `3ac2c3e`. `AUTOMATION_OPPORTUNITY`: gate on `serverpod generate` exit status in CI — blocked by BLOCKER-1. |
| `CONTRADICTION` | G-7 (`9417f8bf`) is `RESOLVED` and makes removing `referenceName` from `RepositoryCredentialView` **required**, but `packages/product_registry/**` is `PROHIBITED` to this lane and the field is still read by `CredentialResponse` (pre-existing). | **G-7 observation** above. Left exactly where it sits; owner `design-agent`. |
| `PROJECT_FACT` | `AccessStatus.verified` was read in nine places and written in zero — a permanently-closed gate that no server behaviour and no operator action could open, and that read as "working as designed". | Fixed, and the write is now covered by a test that fails six others when removed. Executable knowledge, self-verifying. |

Nothing else met the bar for persistence. In particular: the **absence** of
Docker interaction and the fact that `make test-integration` was not needed are
ephemeral to this lane.

---

```yaml
RESULT: IMPLEMENTED

FEATURE: Wire Add Product to the real key service so Register becomes pressable for SHIP IT Platform
BRANCH: impl/client-addproduct-keyflow
BASE_SHA: c110aa243f41d0bedf7dcc6de72b7462173461f6
HEAD_SHA: 2f6b78dfd721598b8ea60ae29ad70194c53a92e1

OWNED_PATHS:
  - apps/control_plane/lib/**          # written: 5 files
  - apps/control_plane/test/**         # written: 2 files
  - packages/control_plane_client/**   # written: 1 file (regenerated)
READ_ONLY_PATHS:
  - apps/server/lib/src/credentials/**
  - apps/server/lib/src/endpoints/credential_endpoints.dart
  - docs/adr/0018-per-product-git-credentials.md
PROHIBITED_PATHS:
  - apps/server/**          # 0 files touched; tracked-file hash identical to base
  - docker/**               # 0 files touched; 0 Docker/Compose commands issued
  - .github/**
  - docs/adr/**
  - .decisions/**           # read only, to report G-7 accurately
  - packages/product_registry/**

FILES_CHANGED:
  - apps/control_plane/lib/data/control_plane_repository.dart         (+183 / −0)
  - apps/control_plane/lib/data/operator_attestation.dart             (+86 / −0, new)
  - apps/control_plane/lib/data/runtime_config_stub.dart              (+7 / −0)
  - apps/control_plane/lib/data/runtime_config_web.dart               (+17 / −4)
  - apps/control_plane/lib/features/products/add_product_page.dart    (+346 / −57)
  - apps/control_plane/test/blocs/add_product_bloc_test.dart          (+814 / −0, new)
  - apps/control_plane/test/helpers/unimplemented_repository_apis.dart (+19 / −0)
  - packages/control_plane_client/lib/src/protocol/client.dart        (+101 / −1)

GATES:
  format=pass   # dart format --output=none --set-exit-if-changed .  → (0 changed), exit 0
  analyze=pass  # cd apps/control_plane && flutter analyze  → No issues found!, exit 0
  tests=pass    # cd apps/control_plane && flutter test  → 266: All tests passed!, exit 0
                #   246 pre-existing at base + 20 new; briefed +190 was stale
                #   0 failures; nothing weakened, skipped, filtered or deleted
  build=n/a     # no build gate briefed for this lane
  runtime=n/a   # no browser run; QA stack untouched, 0 Docker/Compose commands

DISCOVERIES:
  - BLOCKER-1 (apps/server, PROHIBITED): serverpod generate exits 1 --
    CredentialEndpoints.recordCustodyPrecondition (credential_endpoints.dart:105)
    returns SecretProvider, not Future/Stream. Client output still lands and is
    deterministic; server-side generated output is byte-identical to base. Not
    fixed. Owner: apps/server lane. Will fail any CI gate on generate's exit status.
  - BLOCKER-2 (structural, reported not worked around): generate() resolves the
    repository reference before minting, so the durable product row must be written
    during "Check access", not "Register". Register instead guarantees the
    credential row is attached and verified by reading the detail back, and
    refuses otherwise. Dispatch test 3's wording ("Register creates a credential
    row") is unreachable by any client; dispatch requirement 4's wording
    ("Register must leave a credential row that points at the generated one")
    is implemented and tested both ways.
  - BLOCKER-3 (docker, PROHIBITED): config.js.template publishes only
    CONTROL_PLANE_API, so the runtime path for HOST_KEY_FINGERPRINT /
    OPERATOR_NAME yields null until its owner adds them. --dart-define works today.
  - G-7 (9417f8bf, RESOLVED): referenceName still on RepositoryCredentialView
    (generated from a PROHIBITED package) and still read by CredentialResponse
    (pre-existing). Not removed, not added to. MintedDeployKey deliberately does
    not read it, so Add Product adds no new client-side use. Tests assert both.
  - The generated client was stale for TWO reasons, not one: missing
    credentialEndpoints, and createProduct.manifestJson still `required` where the
    server has it optional. Independent confirmation of H-1.
  - Existing errorMessage behaviour replaces the whole page, so an access failure
    is routed to the key box (key present) or the page (no key) rather than
    destroying the form. Server failureReason is documented safe to display.

KNOWLEDGE_PERSISTED:
  - Executable: 20 tests in apps/control_plane/test/blocs/add_product_bloc_test.dart.
    Removing the AccessStatus.verified write fails 6 of them; planting
    Random.secure in lib fails the generator-absence scan by file and token.
  - Executable: the AccessStatus.verified write itself, with the mutation proof.
  - Prose: BLOCKER-1/2/3 and the G-7 observation, in this report only --
    docs/** and .decisions/** are outside this lane's ownership, so nothing was
    written to repository knowledge.
  - Not persisted: Docker non-interaction and the unneeded test-integration run
    (ephemeral to this lane).

BLOCKERS:
  - BLOCKER-1  serverpod generate exits 1 on apps/server/** (PROHIBITED). Not fixed.
  - BLOCKER-2  Register cannot mint the credential; server ordering forbids it.
               Requirement 4's wording implemented and tested; test 3's wording
               is unreachable by any client. Reported for a product decision.
  - BLOCKER-3  runtime config keys not published by docker/config.js.template
               (PROHIBITED). Build-time --dart-define is the working path.
  None of these prevents the change from being correct on its own HEAD; all three
  need an owner outside this lane.

READY_FOR_INDEPENDENT_REVIEW: YES
```