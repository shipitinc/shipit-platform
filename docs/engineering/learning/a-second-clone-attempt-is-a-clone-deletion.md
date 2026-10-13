# Repository Learning: a second clone attempt is a clone deletion

**Feature**: IMPL-A3-WORKSPACE-PROVISIONING (operator-triggered durable workspace provisioning)
**Date**: 2026-10-13
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.

---

## Summary

`DurableWorkspaceRuntime.provision()` has no re-provision, no `force`, and no replacement path. It
refuses a product that already has a durable clone, every time.

That is not caution about a messy state. **Re-provisioning is the destructive path**, and it is
destructive because of how the transport already behaves:

1. A second run materialises into the SAME `$workspaceRoot/$productId` tree, because the product root
   is derived from the product id and nothing else.
2. `git init` against an existing repository succeeds — it is idempotent.
3. `git remote add origin <url>` then **fails**, because `origin` is already there. Exit code 3.
4. `SshDurableWorkspaceMaterializer` treats any non-zero git exit as a failed provisioning, and its
   `on Object` handler **destroys the whole product root** — the existing clone, its `.git` object
   store, and every unreviewed commit in it.

So "just run it again" reads as the helpful recovery and is in fact the only route that deletes a
product's checkout. The refusal is not a policy layered on top of the mechanism; it is the only
answer the mechanism permits.

This is the same shape as the `docker_postgres_data_qa` incident this repository already carries: a
cleanup reached through a path that read as safe, destroying something irrecoverable.

## The executable form

The premise is a test, not a paragraph. Read it rather than this file when you need the behaviour:

| What is true | Where it is true, mechanically |
|---|---|
| A second `git remote add origin` in an existing repository exits non-zero | `apps/server/test/durable_workspace_provision_trigger_test.dart` — "WHY it must refuse: a second materialisation into the same tree would DESTROY the first". Runs real `git` in a temp directory; no network, no ssh. |
| The refusal is total and unconditional | same file — "there is no destructive path in this lane to reach deliberately", which greps the trigger's own source for `delete(`, `remove(`, `force(`, `overwrite(` and friends. |
| A second call changes nothing at all | same file — "the second call is refused and changes nothing", comparing the stored record before and after. |
| It is deterministic, not a first-call-only guard | same file — "DETERMINISTIC across any number of calls". |

That test asserts a property of `git` rather than of this repository's code. If it ever fails, the
refusal has lost the mechanical reason it has and needs a real one before anyone relaxes it.

## What is NOT decided here

**How long a durable clone lives, and who presses it, remain open** — OD-7.2 and OD-7.3, as A1's own
startup banner already states (`reclamationPolicy: none`). Re-pinning a product to a newer commit is
a real need and is deliberately not this lane's job. A lane that needs to reclaim a clone has to
answer those two questions first, and an answer is a human decision, not a `git` invocation.

Until then the total is the safety property: there is no destructive path to reach **deliberately**,
because there is no destructive path at all.

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
  neutral verb anywhere near this subsystem.
