# Repository Learning: A deleted SQL comment renders as the diff's own header

**Task**: IMPL-B6-CORRECTION-QUERY (correction lane, branch `fix/unstick-unreviewable`)
**Date**: 2026-10-15
**HEAD**: 6a8d054 → correction on top (see `apps/server/migrations/20261014210000000/migration.sql`)
**Category**: `PROJECT_FACT` — the measurement is product-specific and evidence-backed; the
generalised check is a **framework candidate**, flagged below and **not** persisted as framework
policy.

---

## Summary

The canonical way to prove "no SQL statement changed" — count deleted lines in `git diff`,
discarding the file header with `startswith('-') and not startswith('---')` — **reports zero
deletions for any `.sql` file whose changes are comment-only.**

It reported 0 here. The truth was 8.

---

## The measurement

Counting `git diff -U0` line prefixes for
`apps/server/migrations/20261014210000000/migration.sql` on a comment-only edit:

| Measure | Value |
|---|---|
| `git diff --numstat` — authoritative | `51  8` (51 added, 8 deleted) |
| Lines matching `^-` | 9 |
| Lines matching `^---` | 9 |
| Of those, the real `--- a/<path>` header | **1** |
| **Real deletions** | **8** |
| The canonical filter `startswith('-') and not startswith('---')` | **0** |

## The precise rule

A deleted line renders in `git diff` as `-` followed by the line's own first character. So a
deleted line is indistinguishable from the `--- a/<path>` file header **iff its first two
characters are `--`.**

In a `.sql` file that is **every comment line**. Other languages are not so exposed:

| File | Comment line | Deleted, as git renders it | Matches `^---`? | Canonical filter correct? |
|---|---|---|---|---|
| `.sql` | `-- text` | `--- text` | **yes** | **no — the deletion is discarded** |
| Dart | `// text` | `-// text` | no | yes |
| Dart | `    // text` (indented) | `-    // text` | no | yes |

The deciding character is the one after the diff's own `-`. SQL's comment marker is `-`, so the
two run together into `---`. Dart's is `/`, so the line reads `-//` and the filter's `startswith('---')`
never fires. That is the entire asymmetry, and it is why the idiom survived: it is right for every
language whose comments do not begin `-`.

## Why it is worse than a wrong number

The filter fails **only** on comment-only SQL changes — precisely the case where a reviewer is
asking "did this edit touch a statement?", and precisely the case where a `0` reads as
reassuring. A reviewer who sees "0 deletions" concludes no SQL was removed. Nothing in the output
contradicts that; the number simply looks like a clean bill of health, and the 8 real deletions
are indistinguishable from the header they sit beside.

It bit this lane directly: an independent `difflib` count said 16 against `git --numstat`'s 17,
for exactly this reason.

## The recommended check

Count deletions by excluding **only the real file header**, not everything matching `^---`:

```bash
M=apps/server/migrations/20261014210000000/migration.sql
# deletions, correct
git diff -U0 -- "$M" | rg '^-' | rg -v '^--- a/' | wc -l
# additions, correct
git diff -U0 -- "$M" | rg '^\+' | rg -v '^\+\+\+' | wc -l
```

Then, separately and more importantly, **classify every changed line** rather than counting them.
For a "no SQL statement changed" claim, the question is not how many lines moved but whether any
of them was executable:

```bash
# must print nothing
git diff -U0 -- "$M" | rg '^\+' | rg -v '^\+\+\+' | rg -v '^\+--'
git diff -U0 -- "$M" | rg '^-'  | rg -v '^--- a/'   | rg -v '^---'
```

The second pair are the deletions of comment lines, each of which happens to begin `-` + `--`.
Anything either command *does* print is a non-comment line: a real edit to a statement.

**`git diff --numstat` should be treated as the authority and the hand-rolled filter as the
thing under test**, because numstat is computed by git rather than by a re-derivation of git's
own text format. A reviewer recomputing a count from diff text should state which of the two they
compared against.

---

## Framework candidate — promotion flagged, not performed

*`WORKFLOW_IMPROVEMENT` requires independent review; this lane does not have that authority and
has not exercised it.*

**Generalisable claim.** Any lane that proves "only comments changed" by filtering `git diff`
output, and any reviewer that verifies it, inherits this blind spot on `.sql` files. The
`startswith('-') and not startswith('---')` idiom is in circulation as *the* provenance check
precisely because it is usually right — it is right for Dart, YAML, JSON, and prose, which is
almost all of what gets reviewed.

**Recommended framework change.** The "prove no statement changed" proof offered during review
should name the header to exclude explicitly (`^--- a/<path>`) rather than a prefix, and should
additionally require the changed lines to be *classified* — added/deleted line counts are a
sanity check; "is any of it executable" is the claim. A framing that makes the failure mode
visible is itself the mitigation: **the check must be able to report zero deletions on a
comment-only SQL edit without that reading as "nothing was deleted".**

Two supporting points for whoever takes this to review:

- The asymmetry is a property of *comment syntax*, not of SQL. The same repo's Dart files are
  immune, which is why the idiom survived. Any language whose comments begin `--` — SQL, Python,
  Haskell, Lua, Erlang, Ada — reproduces it exactly, and every language whose comments begin `//`
  or `#` is immune. That makes this a **class** of defect, not a single-file quirk.
- The failure is silent and directionally reassuring, which is the property that makes a
  verification step worth writing down at all. A check that cannot report its own failure mode is
  not a check; it is a comment.

## Where the trap was confirmed

The generalisation is not inferred from one file. It was measured by an independent reviewer
across this correction's diff: git `--numstat` said 17 deleted, the canonical filter said 0, and
18 lines matched `^---` = 1 file header + 17 real deletions. That reviewer also recorded that it
**does not fire for Dart `//` comments** — the reason given above — which is what makes this a
syntax-specific trap rather than a general one about diff headers.