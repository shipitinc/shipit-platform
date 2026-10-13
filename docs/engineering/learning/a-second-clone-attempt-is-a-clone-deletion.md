# Repository Learning: a second clone attempt is a clone deletion

**Feature**: IMPL-A3-WORKSPACE-PROVISIONING (operator-triggered durable workspace provisioning)
**Date**: 2026-10-13
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.

---

## Summary

**The refuse-always guard is in `DurableWorkspaceProvisionTrigger`, and nowhere else.**
`DurableWorkspaceRuntime.provision()` and `SshDurableWorkspaceMaterializer.materialize()` have
**no idempotence guard of their own** — neither of them checks whether a product already has a
clone, and both will happily run a second time if anything calls them. The single check that
refuses a re-provision is guard #5 in `DurableWorkspaceProvisionTrigger.provision`
(`apps/server/lib/src/services/control_plane_service.dart`), which reads the onboarding record
before asking A1 for anything.

So "the runtime is safe to call twice" is false, and the correction matters because a second
call is the **destructive path**. It is destructive because of how the transport already
behaves:

1. A second run materialises into the SAME `$workspaceRoot/$productId` tree, because the product root
   is derived from the product id and nothing else.
2. `git init` against an existing repository succeeds — it is idempotent.
3. `git remote add origin <url>` then **fails**, because `origin` is already there. Exit code 3.
4. `SshDurableWorkspaceMaterializer` treats any non-zero git exit as a failed provisioning, and its
   `on Object` handler **destroys the whole product root** — the existing clone, its `.git` object
   store, and every unreviewed commit in it.

So "just run it again" reads as the helpful recovery and is in fact the only route that deletes a
product's checkout. The trigger's refusal is not a policy layered on top of the mechanism; it is
the only answer the mechanism permits.

**Therefore: never call `DurableWorkspaceRuntime.provision()` or
`SshDurableWorkspaceMaterializer.materialize()` directly.** Go through
`DurableWorkspaceProvisionTrigger`, which is where the refusal lives. A direct call skips it, and
"skips it" and "deletes the clone" are the same action here.

This is the same shape as the `docker_postgres_data_qa` incident this repository already carries: a
cleanup reached through a path that read as safe, destroying something irrecoverable. That is
exactly why this correction is about *attribution*: a persisted statement that assigns the safety
property to the wrong class is how the next lane ends up calling the unguarded one.

## The executable form

The premise is a test, not a paragraph. Read it rather than this file when you need the behaviour:

| What is true | Where it is true, mechanically |
|---|---|
| A second `git remote add origin` in an existing repository exits non-zero | `apps/server/test/durable_workspace_provision_trigger_test.dart` — "WHY it must refuse: a second materialisation into the same tree would DESTROY the first". Runs real `git` in a temp directory; no network, no ssh. |
| The refusal is total and unconditional **within the trigger**, and the capability is gated where
  the trigger does not reach | same file, two tests. "there is no destructive path in this lane to
  reach deliberately — as a CLOSED SET of calls the trigger may make" enumerates every
  `runtime.…` / `provisioner.…` the trigger can invoke, so a NEW call of any name fails. "the
  destructive CAPABILITY is named outside the mechanism only by the trigger" then greps `lib/` for
  `DurableWorkspaceRuntime` / `DurableWorkspaceProvisioner` /
  `DurableWorkspaceMaterializer` and fails if anything outside A1's mechanism modules, the trigger,
  and `server.dart`'s construction of the runtime names it — and `server.dart` itself may not call
  `.provision(` on anything but `trigger`. |
| **The runtime and the materialiser have no guard of their own** — the attribution this correction
  exists to fix | `DurableWorkspaceProvisioner.provision()`
  (`apps/server/lib/src/baseline/durable_workspace_runtime.dart`) runs pin → credential → host-key
  → access → `resolveRepository` → `materialize`, and contains no already-provisioned check at any
  point. Called directly a second time, it materialises again into the product root that already
  holds the clone. The gate above is what keeps anyone from discovering that. |
| A second call through the trigger changes nothing at all | same file — "the second call is refused
  and changes nothing", comparing the stored record before and after. |
| It is deterministic, not a first-call-only guard | same file — "DETERMINISTIC across any number
  of calls". |

**What these gates do not prove.** Neither reads every line: a helper written inside
`control_plane_service.dart` and called from code the trigger does not reach is not covered by
either, and no grep over source text is. What they do is fail CI on the ordinary accident — a new
lane calling `DurableWorkspaceRuntime.provision()` because it is the obvious API to call. Review
still owns the rest.

That test asserts a property of `git` rather than of this repository's code. If it ever fails, the
refusal has lost the mechanical reason it has and needs a real one before anyone relaxes it.

## What is NOT decided here

**How long a durable clone lives, and who presses it, remain open** — OD-7.2 and OD-7.3, as A1's own
startup banner already states (`reclamationPolicy: none`). Re-pinning a product to a newer commit is
a real need and is deliberately not this lane's job. A lane that needs to reclaim a clone has to
answer those two questions first, and an answer is a human decision, not a `git` invocation.

Until then the safety property is the trigger's: it answers "refused" on every call, and the two
gates above check that nothing reaches the capability around it. That is what the property is —
not a claim that the destructive path has been designed away, which it has not.

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
