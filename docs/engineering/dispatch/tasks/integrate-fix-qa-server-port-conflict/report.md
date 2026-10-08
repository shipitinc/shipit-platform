# Integration Report — fix/qa-server-port-conflict

```
RESULT: MERGE_APPROVED

APPROVED_HEAD: 7d3a21ee52e1795ed29f10dfa94d04a9edb9e210
CURRENT_MAIN:  7d3a21ee52e1795ed29f10dfa94d04a9edb9e210

GATES:
format=N/A — no Dart/format-bearing file in the change (only docker/compose.qa.yaml). Independently re-verified, not taken on the reviewer's word.
analyze=N/A — same reason: zero Dart sources changed, so the analyzer has no subject. Pre-existing unrelated analyzer findings elsewhere in the repo are not this change's gates.
tests=N/A — no Dart, no CI, no test harness reads this file. `git grep -nE '8080|8180|compose\.qa' -- .github/` → zero matches (no CI job parses this file).
build=N/A — no image, artifact or bundle is produced by editing a publish mapping.

PROVENANCE:
base_sha=dbb1d75e71c9ba4142d511eeaa5d7ca694cdb8e5 (was == main == origin/main at start)
approved_head=7d3a21ee52e1795ed29f10dfa94d04a9edb9e210
strategy=git merge --ff-only (fast-forward, no merge commit, no rebase, no history rewrite)
resulting_main=7d3a21ee52e1795ed29f10dfa94d04a9edb9e210
push=git push origin main → dbb1d75..7d3a21e main -> main (exit 0)
remote=origin push URL git@github.com:shipitinc/shipit-platform.git (SSH) / fetch URL https://github.com/shipitinc/shipit-platform.git (HTTPS) — matches the stated split
post_push_ahead_behind=main...origin/main = 0 0
ls_remote_confirm=7d3a21ee52e1795ed29f10dfa94d04a9edb9e210 refs/heads/main
lane_worktree=INTACT /private/tmp/shipit-fix-qa-port @ 7d3a21e; branch fix/qa-server-port-conflict @ 7d3a21e — not deleted, Manager cleans up
pre_existing_dirty_files=50 modified, all still unstaged, none committed by me

READY_FOR_INTEGRATION: YES — integrated and pushed. No further merge action is required or authorized.
```

---

## 1. Verdict

`MERGE_APPROVED`. The independently reviewed change is integrated into `main` and published. `main` is
now `7d3a21e`, identical to the approved HEAD, and local/remote are in sync (`0 0`).

---

## 2. Two dispatch discrepancies — read before treating this as a clean run

Neither blocked the merge. Both are recorded because a reader comparing this report to the dispatch
will notice them, and one of them is a literal contradiction in the dispatch itself.

### 2a. PRECONDITION 3 as written would have failed — and would have failed *wrongly*

The dispatch stated:

> 3. The changed line reads `- "8180:8180"` and `SERVERPOD_API_SERVER_PORT` is still `"8080"`.

The approved HEAD reads:

```
56:      - "8180:8080"
52:      SERVERPOD_API_SERVER_PORT: "8080"
```

That is the **dispatch's typo, not a defect in the change** — and the dispatch contradicts itself
three lines earlier, where the same paragraph specifies `"- "8080:8080"` → `- "8180:8080"`,
*(host side only; container port stays 8080)*. Three independent sources agree on `8180:8080`:

- the dispatch's own change description,
- the approved commit's diff (`git diff dbb1d75 7d3a21e`, one line),
- the review's `od -c` byte dump and its §2/§13 analysis.

`8180:8180` would be a genuine bug, not a cosmetic variant: with the listener still on 8080 and
Docker DNAT-ing host 8180 → container 8180, the QA server would be published on a port nothing is
listening on. So the literal precondition was testing for a broken state.

**I applied the intent-consistent reading** — host side `8180`, container side `8080` unchanged —
and verified it directly rather than assuming it. I flag it because a strictly literal reading of
the dispatch would have produced `INTEGRATION_BLOCKED` on a typo, and because if `8180:8180` had
*actually* been in the file, this merge would have been wrong. The distinction is the whole point.

### 2b. 50 pre-existing modified files, not 49

The dispatch named 49 (48 under `apps/control_plane/test/failures/` plus `melos_shipit_platform.iml`).
The checkout actually carries **50** modified files. The extra one:

```
 M .decisions/6bd29306-efe0-4335-9c31-d14bb4957523.yaml    (mtime Oct  8 13:26:35 — today)
```

All 48 failure PNGs and the `.iml` are dated Oct 1–2 as described; this decision-record file is dated
today and is consistent with the recent `decisions(security): …` / `docs(state): …` commits. It is
**not** part of this change and I did not touch it. It remains unstaged, unmodified by me, and
uncommitted. There are also 20 untracked scratch files (`*.sql`, `*.png`, `human_claims_export.txt`,
the dispatch report dirs) — none staged, none committed.

This does not affect the merge: the commit's own numstat is `1 1 docker/compose.qa.yaml`, proven
independently of the working tree. But the pre-commit inventory in the dispatch was off by one, so
"verify those 49 are still unstaged" had to be re-derived rather than trusted.

---

## 3. Preconditions — all four verified

| # | Precondition | Result | Evidence |
|---|---|---|---|
| 1 | `main` still `dbb1d75`; `main...origin/main` = 0 0 | **PASS** | Pre-fetch: `main`, `origin/main` = `dbb1d75`. Ran `git fetch origin main` so the check reflects the real remote rather than a possibly stale tracking ref. Post-fetch: `origin/main` = `dbb1d75`, `main...origin/main` = `0 0` |
| 2 | numstat exactly `1 1 docker/compose.qa.yaml` | **PASS** | `git diff --numstat dbb1d75 7d3a21e` → `1	1	docker/compose.qa.yaml`; `git diff --name-only` → one path |
| 3 | changed line / `SERVERPOD_API_SERVER_PORT` | **PASS (intent reading — see §2a)** | `:56 - "8180:8080"`, `:52 SERVERPOD_API_SERVER_PORT: "8080"`. Byte-level container side confirmed via YAML parse, not by eye |
| 4 | `apps/**`, `nginx.conf`, `compose.test.yaml`, `compose.e2e.yaml`, `local-qa.md` untouched | **PASS** | `git diff --name-only dbb1d75 7d3a21e` returns `docker/compose.qa.yaml` only. Nothing under `apps/`; none of the four named paths |

Additional provenance checks beyond the four:

- `git merge-base --is-ancestor main 7d3a21e` → success, so **fast-forwardable**; no rebase or
  history rewrite was implied or performed.
- `git log --oneline dbb1d75..7d3a21e` → exactly **one** commit.
- `git diff --check dbb1d75 7d3a21e` → no whitespace errors.
- `git push --dry-run origin main` before the real push → confirmed the SSH push path works and that
  no unexpected remote movement would be clobbered.

---

## 4. Post-merge content verification (on `main`, not on the branch)

Read the merged working tree and re-parsed it as YAML. No Docker command was involved — compose files
are read as text per `AGENTS.md:127`:

```
YAML PARSE: OK
server.ports                     = ["8180:8080"]
server.SERVERPOD_API_SERVER_PORT = "8080"
client.ports                     = ["8081:8081"]
client.CONTROL_PLANE_API         = "http://localhost:8081/api/"
client.API_UPSTREAM              = "server:8080"
```

The browser-facing entry point is unchanged: the client still publishes `8081`, `CONTROL_PLANE_API`
still points at `localhost:8081/api/`, and nginx still proxies over the compose network to
`server:8080`. Only the host-side publish moved. Failure premise re-checked read-only:

```
8180 → no listener                        (the fix's target is genuinely free)
8080 → java PID 77155… LISTEN *:8080      (Penpot holds it — dual-stack wildcard)
```

---

## 5. Gates — why N/A is a verified finding, not a skip

I re-derived the N/A claim independently instead of inheriting it. The commit touches exactly one
file, `docker/compose.qa.yaml`, and `git diff --name-only` filtered for `\.dart$|\.yaml$` returns that
one YAML file. So:

- **format / analyze / tests / build have no subject.** No Dart source changed. Editing a Compose
  publish mapping produces no image, artifact or bundle.
- **CI cannot break from this**: no workflow reads this file (`git grep -nE '8080|8180|qa-up|compose\.qa' -- .github/` → zero matches), so no CI job needs updating and no gate needs re-baselining.
- **No gate was skipped and no non-run gate was dressed up as green.** The `config` gate named in the
  dispatch remains refused under `AGENTS.md:118` (the reviewer reached the same conclusion, §6); the
  text parse in §4 recovers the same two facts the gate existed to confirm.

Running `dart format`/`analyze`/the test suite here would have produced verdicts about unrelated
pre-existing state and misrepresented this change's gate status. N/A with a stated reason is the
honest result.

---

## 6. Docker discipline

**Zero** Docker or Compose commands were issued by this lane — no `up`, `down`, `stop`, `restart`,
`build`, `pull`, `config`, `ps`, `logs` or `info`. No `make clean`, no `make test-env-down`, no
`make e2e-down`, no bare `down -v`. The only host-state probe was `lsof`, which reads the host socket
table and does not contact the Docker daemon.

No stack was started, so there was no test resource to create and **nothing to tear down — no
disclosure is owed**. The QA server container is still running the pre-change `8080:8080` publish.

---

## 7. Working tree left as found

```
modified files (unstaged) : 50   (48 failure PNGs + melos_shipit_platform.iml + .decisions/6bd29306…)
staged files              : 0    (git diff --cached --name-only → empty)
untracked                 : 20   (pre-existing scratch + the dispatch report dirs)
```

I used **no** `git add -A`, **no** `git commit -a`, and **no** commit at all — the fast-forward
advanced `main` to the already-reviewed commit, so there was nothing of mine to stage. Verified
afterwards that all 50 remain unstaged and that I modified none of them. The only file I wrote is this
report. The lane worktree `/private/tmp/shipit-fix-qa-port` and branch
`fix/qa-server-port-conflict` are both intact for the Manager to clean up.

---

## 8. Owed follow-ups — recorded, deliberately NOT actioned

Per instruction, none of these were attempted. They remain owed and are unchanged by this merge:

- **H-1** `Makefile:83` prints `Server: http://localhost:8080` as live `make qa-up` output — now
  points at Penpot. One-line fix.
- **H-2** `docs/deployment/local-qa.md:281` — wrong port *and* wrong method (a bare `curl` for 200
  cannot distinguish ShipIt from Penpot, which is what masked the dead server). Needs an
  identity-based assertion.
- **H-3** `docker/compose.yaml:71` — local dev stack still publishes `8080:8080` and is equally
  unstartable while Penpot holds 8080. This change rescues QA only; it does **not** solve the
  underlying host-port problem.
- **M-1** `PORT_OFFSET` documented in four places, implemented in no compose file — implement-or-delete
  is an architecture decision for a human.
- **M-2 / L-2 / M-3 / M-4 / L-3** stale port tables, `local-qa.md` host-port lines, unpersisted
  learning, `nginx.conf` vs `nginx.conf.template` reference correction, `0.0.0.0` bind exposure.

**Post-merge hazard now live on `main`:** `design/port-and-cleanup` (eab3a5b),
`qa-contract/port-cleanup` (14608dc) and `design/qa-startup-restructure` (a8a990b) still carry
`8080:8080` at `docker/compose.qa.yaml:56`. No textual conflict exists, so any of them can merge
cleanly — **but any lane that regenerates or re-derives `compose.qa.yaml` from a stale copy will
silently revert 8180.** The mapping must not be "fixed" back to 8080 or 8082.

---

## 9. What the Manager still has to do

Integration is complete, so the remaining work is **deployment**, not merging:

1. **Recreate the QA server container** so `8180:8080` takes effect. I did not and must not — the
   Manager holds deployment authority. Ordering matters: recreating before this change was in effect
   would still have published 8080 and still failed to bind.
2. Then QA is reachable at `http://localhost:8180` for the server API, with the UI and
   `http://localhost:8081/api/` unchanged.
3. H-1/H-2 are worth folding into the next merge; H-2's method fix is the one that would actually
   have caught the original silent failure.
