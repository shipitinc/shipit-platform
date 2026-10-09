# Dispatch — fix-hostkey-config-wiring

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: fix-hostkey-config-wiring
TASK_TYPE: correct
FEATURE: Deliver the host-key attestation values to the client in the docker path
AREA: docker entrypoint allowlist + compose passthrough + client config template
WORKTREE: /private/tmp/shipit-fix-hostkey-config
BRANCH: fix/hostkey-config-wiring
BASE_SHA: c110aa2
OWNED_PATHS:
  - docker/entrypoint.client.sh
  - docker/compose.qa.yaml
  - docker/config.js.template
READ_ONLY_PATHS:
  - docker/build-client.sh
  - docker/Dockerfile.client
  - apps/control_plane/lib/**
  - docs/engineering/dispatch/tasks/fix-generate-and-hostkey-config/report.md
PROHIBITED_PATHS:
  - apps/**
  - packages/**
  - .github/**
  - docs/adr/**
  - .decisions/**
  - .github/workflows/**
ACCEPTANCE_CRITERIA: >
  The client receives host-key fingerprint and operator name from the environment in the docker
  path, unexpanded placeholders never reach the served bundle, and no value is hardcoded.
VALIDATION_COMMANDS:
  - bash -n docker/entrypoint.client.sh
ROUTING_CLASS: STANDARD
```

---

## Why this lane exists

The Add Product flow needs two operator-asserted values to reach the Flutter web client in the docker stack:
`SHIPIT_HOST_KEY_FINGERPRINT` and `SHIPIT_OPERATOR_NAME`. `verifyAccess` on the server requires them, and
the client currently reads **null** for both.

A prior lane attempted this and **correctly refused to finish it**. Its finding, which you should verify
rather than inherit:

> `entrypoint.client.sh:8` uses **envsubst's allowlist form**, so the placeholders come out as **literal
> strings**. Because the client treats any non-blank value as configured, a template-only edit would ship a
> literal `${SHIPIT_HOST_KEY_FINGERPRINT}` **presented to the operator as a fingerprint** — worse than
> today's `null`.

That is a real trap and it is why this needs three files instead of one.

## What to do

1. **`docker/entrypoint.client.sh`** — add the two variable names to the envsubst **allowlist** so they are
   actually substituted. Read the script and preserve its existing style and failure behaviour.
2. **`docker/compose.qa.yaml`** — pass both through to the client service using `${VAR:-}` so an unset value
   stays **empty rather than literal**, and so nothing is hardcoded. Do **not** introduce a default value
   for the fingerprint: an unset host key must not look configured.
3. **`docker/config.js.template`** — wire the values into the client's runtime config, matching the
   template's existing substitution style. Do not invent a second mechanism.

## The failure mode you must design against

**An unset value must be observably unset.** The client treats any non-blank value as configured, so the
worst outcome is a literal placeholder or an empty-but-truthy value being presented to the operator as a
host key fingerprint. That is a security-relevant lie in the UI, and it is worse than the `null` you are
replacing.

So: unset → empty/unset, never a literal `${...}`, never a default. Prove both directions.

## Semantics you must not misrepresent

These two values are **operator-asserted, not server-verified** — open finding M-5 from the key service
review. Whatever you do must not imply they are verified, and must not hardcode any value. Keep them
substitutable from the environment. GitHub publishes its SSH host key fingerprints; the point of surfacing
them for operator confirmation depends on them arriving unset-by-default and honestly labelled.

## Hard constraints

- **ZERO mutating Docker/Compose commands.** No `up`, `down`, `build`, `stop`, `restart`, `pull`. You are
  editing text files. **The QA stack is up and healthy on a stopgap run-mode override — do not disturb it.**
- Read compose files and scripts as **text**. Do not start a stack to find out what it does.
- `docker/compose.test.yaml` and `docker/compose.e2e.yaml` are **out of scope** — they have their own
  recorded scoping problems and are not part of the client path you are wiring.
- Do not touch `apps/**` or `packages/**`. The client and server changes are merged or under review
  elsewhere.
- Do not modify `.github/workflows/**`.
- **Do not add a top-level `name:` to any compose file.** `AGENTS.md` § Shared Docker state records that
  `docker/compose.qa.yaml` resolves to compose project `docker`, which **is the live QA stack's project**.
  Adding `name:` would silently re-home that stack and leave data on disk under the old name. If you believe
  a project rename is warranted, report it as a finding — do not do it.

## Validation

`bash -n docker/entrypoint.client.sh` for syntax. You may also **simulate** the substitution with envsubst
against a temporary copy outside the repository to prove both directions (set → substituted; unset → empty,
not literal). Do that in the session temp dir, not in the repo.

## Proof required

1. Set → the served config carries the real value.
2. Unset → the served config carries **empty**, never the literal `${SHIPIT_HOST_KEY_FINGERPRINT}`.
   Show both.
3. Nothing hardcoded — no fingerprint or operator name appears literally in any of the three files.
4. `bash -n` clean.

## Report requirements

1. The envsubst allowlist change and why the literal-placeholder failure was real — demonstrate it, don't
   assert it.
2. The compose passthrough form you used and why `${VAR:-}` rather than a required variable. Note:
   `AGENTS.md` records that a mandatory variable (`${VAR:?...}`) in a shared compose file breaks **every**
   command that reads that file, including read-only ones, because Compose interpolates the whole file
   before filtering. Respect that.
3. Anything you could not do and why.

## Other lanes

A focused review of the key service's `serverpod generate` fix is running read-only on `apps/server/**`.
**No overlap.** `impl/client-addproduct-keyflow` is complete at `2f6b78d`, owning
`apps/control_plane/**` and `packages/control_plane_client/**`.

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.

## Cleanup

Commit on your branch. **Do not push, merge, or touch `main`.** Start nothing, so nothing to tear down.

Report `READY_FOR_INDEPENDENT_REVIEW: YES`. You cannot approve your own work.