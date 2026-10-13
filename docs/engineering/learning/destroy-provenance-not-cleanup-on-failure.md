# Repository Learning: "nothing was returned" is not a reason to delete

**Feature**: IMPL-A1B-MATERIALIZER-ORIGIN (correction lane)
**Date**: 2026-10-13
**HEAD**: dfe1d5f (corrected from 9d0e80e)
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.

---

## Summary

`SshDurableWorkspaceMaterializer.materialize` ended its failure handler with:

```dart
} on Object {
  // Nothing has been handed to a caller on any failure path, so there is
  // nothing to preserve.
  if (!_destroy(root)) { throw DurableWorkspaceCleanupException(root.path); }
  rethrow;
}
```

The comment is true and the code is a data-loss bug, because the sentence is about the
**descriptor** and is being used to license destroying a **tree**. No descriptor exists on
a failure path; `$workspaceRoot/$productId` nonetheless holds a git clone with its object
store and every unreviewed commit an implementation lane has made into it.

The rule that replaced it: **a class removes a directory only when it created that
directory in this call.** Provenance, not "was a result handed back".

## Why it was reachable in ordinary operation, not only on a crash

Reproduced with real git in this lane:

```
$ git init --quiet .            # against an EXISTING repository
$ echo $?                       # 0   <- idempotent, succeeds
$ git remote add origin ssh://git@remote.test:22/org/repo.git
error: remote origin already exists.
$ echo $?                       # 3   <- the non-zero exit the materialiser throws on
```

So a second `provision()` against an existing checkout walks past `init` (exit 0), fails at
`remote add` (exit 3), and the failure handler deleted the checkout. **"Re-provision" was
the destructive verb.** An orphan tree is the same defect by another route: `provision()`
materialises, then writes the onboarding record; if the record write fails, the tree is
left with no record and the next instruction destroys it on its way to the same error.

## The generalisable shape

Three questions that looked equivalent and are not:

1. "Was a descriptor returned?" — about the **result**.
2. "Is this state mine?" — about **provenance**, and the only one that licenses deletion.
3. "Is this state junk?" — about **content**, and unknowable from the filesystem.

Asking (1) to authorise a recursive delete is the bug. `RepositorySnapshot`'s retain test
asks (3), on a tree it is documented to own — that ownership is why it is sound there and
why the durable clone needed its own type.

## Why the weaker definitions of "mine" all fail the same way

| Option | Question it actually answers | How it loses |
|---|---|---|
| Marker file the class wrote earlier | "did *some* call, ever, create this" | A tree a lane has since committed into still carries the marker — the marker survives, the evidence that it is now somebody's work does not factor in |
| `git rev-parse --git-dir` | "is there a repository here" | A real product checkout **is** a repository, so the probe classifies the most valuable thing under the root as the thing to delete. Also cannot describe an empty directory, and spawns a process to re-derive a fact `Directory.existsSync` states exactly |
| Delete only `checkout/`, keep the root | "the root is not the clone" | Still deletes the previous run's clone; once the entry guard refuses, there is nothing to delete anyway |
| **Existence check (chosen)** | **"did *this* call create it"** | Cannot be fooled by the contents of the thing being judged; no process, no network, no trust in state this class wrote on an earlier run |

All the weaker options degrade in the same direction — toward deleting state somebody else
put there — because each substitutes a question about *content* or *history* for one about
*provenance*.

## Two independently load-bearing layers

Mutation testing showed removing either one alone still deletes the tree:

- Removing the **entry refusal** → the run reaches `remote add`, exits 3, destroys.
- Removing only the **`createdRoot &&` condition on the destroy**, entry refusal intact →
  the refusal *itself* throws inside the `try`, is caught by `on Object`, and destroys.
  **Refusing became the deletion.**

The second is the one worth remembering. A guard that throws from inside the try block is
still flowing through the very cleanup path it was meant to constrain, so the cleanup has
to be conditioned on ownership too. A guard is not a substitute for making the destructive
path provenance-aware; they are the same requirement expressed twice.

`createdRoot` is also claimed **before** `createOwnerOnlyDirectory`, not after it returns.
That helper creates then chmods, so a permission failure leaves a real directory and
throws; claiming afterwards hands it to nobody.

## Keeping the tree is not keeping the credential

These are separate obligations and the fix had to hold both. The `finally` still destroys
the identity, `known_hosts` and wrapper unconditionally; the collision path simply never
wrote them. A guard that protects a tree by declining to clean up satisfies every tree
test and breaks R-9 — which is why "keeping the tree does not keep the credential" is
asserted as its own test rather than assumed.

## Executable knowledge

`apps/server/lib/src/baseline/durable_workspace_materializer_test.dart`, group
`a product root this call did not create is never destroyed`. Ten tests, run against
**real git** behind a recording shim (the stub used elsewhere in that file would be
asserting its own behaviour, not git's). The headline test asserts the commit **survived**
— `git rev-parse HEAD` unchanged and `git log` still listing it — rather than merely that
an exception was thrown, because a fix that refused loudly while still deleting would
satisfy every other assertion in the file.

The `COUNTERPART` test asserts the inverse (a root *this* call created is still removed on
failure), so "stop deleting" cannot be satisfied by "stop cleaning up".

## Consequence, stated plainly

`materialize` is now **not re-entrant**, deliberately. A second call into the same root
fails loudly and destroys nothing. The separate lane's record-based already-provisioned
check becomes belt-and-braces rather than load-bearing; the materialiser is correct without
it, and a direct call that bypasses the trigger is safe for a different reason than the
one that motivated the trigger guard.