#!/usr/bin/env bash
#
# Guard: the hand-maintained schema bootstrap is complete, consistent with its
# applier, and equivalent to the migration that creates the same objects on the
# chain-migrated path.
#
# WHY THIS EXISTS. `melos run verify:schema-deviations` greps three literal
# patterns out of the latest `definition.sql`. It cannot see anything the
# Serverpod model-driven generator cannot render, so the class of drift it was
# meant to catch passed silently while every fresh database — CI included — was
# missing the design-revision immutability trigger, the design-review
# independence trigger, the one-approved-revision-per-work-item index and the
# one-active-credential-per-repository index.
#
# PARITY IS CHECKED AGAINST THE WHOLE CHAIN, NOT ONE MIGRATION. An object added
# after 20260920232118956 belongs in its own migration directory, so requiring
# every object to appear in that one file would report a correct later migration
# as a divergence. The chain is the concatenation of every `migrations/*/
# migration.sql`, which is what a chain-migrated database actually replays. The
# single reference migration is still used for the guarded-column comparison,
# because that is specifically about the immutability function it defines.
#
# NAME-ANCHORED PARITY IS NOT PARITY. Finding `CREATE UNIQUE INDEX ... "<name>"`
# says the object EXISTS in both homes; it says nothing about whether they
# declare the same thing. The two copies of
# `product_credential_active_repository_unique` could disagree about the table,
# the key column or the WHERE predicate and every name-anchored check here would
# still pass — while a fresh database and a chain-migrated one enforced different
# invariants. So the index objects are additionally compared by their FULL DDL.
# That check is what makes the "byte-identical" claim in
# `tool/schema_bootstrap.sql` true rather than aspirational.
#
# WHY THIS IS A STATIC CHECK. The fresh-vs-chain difference is a property of the
# SQL that each path applies, not of any particular database:
#
#   * fresh database      -> latest definition.sql  (regenerated from models)
#                            + tool/schema_bootstrap.sql   (hand-maintained)
#   * chain-migrated      -> every migration.sql     (hand-maintained history)
#
# Asserting that the bootstrap asset and the migration declare the same objects
# with the same enforcement, and that no generated definition.sql is being relied
# on to supply them, is a deterministic check of exactly that difference. The
# runtime half — that a real fresh database rejects a tampered approved
# revision — is asserted in CI by `apps/server/tool/schema_bootstrap.dart`,
# which runs against the live test database and exits non-zero if it does not
# hold.
#
# Exit codes: 0 all checks passed, 1 at least one failed, 2 the guard itself
# could not run (a file it depends on is missing) — never a silent pass.
#
# "Never a silent pass" is the load-bearing claim, so it is asserted the only way
# it can be: every check matches the DDL that creates an object, with SQL
# comments stripped first. A `--`-commented section header that names an object is
# not that object, and a bare substring search cannot tell the two apart.
#
# Run: apps/server/tool/verify_schema_bootstrap.sh   (from anywhere)
# Wired into .github/workflows/ci.yaml, job `schema-guard`.

set -uo pipefail

server_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "${server_dir}/../.." && pwd)"

asset="${server_dir}/tool/schema_bootstrap.sql"
applier="${server_dir}/tool/schema_bootstrap.dart"

# The migration that first created the design-revision objects by hand. Its
# `migration.sql` is still the reference for the guarded-column comparison in
# check 3, which is specifically about that function.
reference_migration="${server_dir}/migrations/20260920232118956/migration.sql"

# Every `migration.sql` a chain-migrated database replays, concatenated. This —
# not the single reference migration — is the true chain path: Serverpod applies
# every version after the recorded one (`migration_manager.dart`
# `_getVersionsToApply`), and objects legitimately land in different migrations
# as they are added over time. Anchoring parity on one file would have made a
# later migration for a new object look like a fresh-vs-chain divergence.
chain_migrations=("${server_dir}"/migrations/*/migration.sql)

ci_workflow="${repo_root}/.github/workflows/integration.yaml"
makefile="${repo_root}/Makefile"

status=0

fail() {
  echo "FAIL: $*"
  status=1
}

ok() {
  echo "OK:   $*"
}

# Objects every fresh and chain-migrated database must have, as `kind:name`.
# The kind is not decoration: it is what lets checks 1 and 3 anchor on the DDL
# that creates the object instead of on its name.
required_objects=(
  "trigger:trigger_design_revision_immutability"
  "trigger:trigger_design_review_independence"
  "index:design_revision_approved_unique_per_work_item"
  "index:product_credential_active_repository_unique"
)

# The DDL statement that must create <kind> "<name>". `[^;]*` stops the match
# from running past the end of the statement, so a name cannot be borrowed from a
# later one.
ddl_pattern() {
  case "$1" in
    index)   printf 'CREATE[[:space:]]+UNIQUE[[:space:]]+INDEX[^;]*"%s"' "$2" ;;
    trigger) printf 'CREATE[[:space:]]+TRIGGER[[:space:]]+"%s"' "$2" ;;
    *)       printf 'CREATE[^;]*"%s"' "$2" ;;
  esac
}

# SQL comments are removed before anything is matched against a .sql file.
#
# This is load-bearing, not tidiness. Each object below is announced by a
# `--`-commented section header in both files, so a substring search for the bare
# name is satisfied by that comment alone: deleting the entire CREATE UNIQUE
# INDEX statement, or the entire independence trigger together with its function,
# left the header comments in place and this guard still exited 0. A guard that
# reads as coverage while the database is unenforced is the one failure mode it
# exists to prevent, so comments are stripped and the DDL is matched instead.
# `DROP TRIGGER IF EXISTS "name"` deliberately does not satisfy the trigger
# pattern, so deleting the CREATE while leaving the DROP is caught too.
#
# Matching goes through a herestring, not a pipe: `grep -q` closes the pipe as
# soon as it matches, which under `set -o pipefail` would surface the writer's
# SIGPIPE as the pipeline's status and report a false failure.
sql_without_comments() {
  sed 's/--.*$//' "$1"
}

# ---------------------------------------------------------------------------
# 0. Fail closed if the guard cannot run.
# ---------------------------------------------------------------------------
for required in "${asset}" "${applier}" "${reference_migration}"; do
  if [ ! -r "${required}" ]; then
    echo "FAIL: cannot run the guard, missing or unreadable: ${required}"
    exit 2
  fi
done
if [ ! -s "${asset}" ]; then
  echo "FAIL: ${asset} is empty"
  exit 2
fi
echo "guard: verifying ${asset#${repo_root}/}"

# ---------------------------------------------------------------------------
# 1. The asset DECLARES each required object — by the statement that creates it,
#    matched against the file with SQL comments stripped. A name mentioned in a
#    comment does not count; see sql_without_comments above.
# ---------------------------------------------------------------------------
asset_ddl="$(sql_without_comments "${asset}")"
for entry in "${required_objects[@]}"; do
  kind="${entry%%:*}"
  object="${entry#*:}"
  if grep -qE "$(ddl_pattern "${kind}" "${object}")" <<<"${asset_ddl}"; then
    ok "bootstrap asset creates ${kind} ${object}"
  else
    fail "bootstrap asset does not create ${kind} ${object}; a mention of the name is not the DDL"
  fi
done

# ---------------------------------------------------------------------------
# 2. The applier asserts every required object, so a bootstrap that silently
#    fails to take effect exits non-zero instead of reporting success. The two
#    sides must not drift apart: a rename on one side only would leave the
#    other checking for an object that no longer exists.
# ---------------------------------------------------------------------------
for entry in "${required_objects[@]}"; do
  kind="${entry%%:*}"
  object="${entry#*:}"
  if grep -qF -- "'${object}'" "${applier}"; then
    ok "applier verifies ${object}"
  else
    fail "applier does not verify ${object}; a bootstrap that failed to apply would pass silently"
  fi
done

# ---------------------------------------------------------------------------
# 3. PARITY: the bootstrap and the chain-migrated path enforce the same things.
#    Same object names — anchored on the same kind of DDL as check 1, for the
#    same reason — and the same set of guarded columns in the immutability
#    function: a column present in one and absent in the other is a
#    fresh-vs-chain divergence in either direction.
# ---------------------------------------------------------------------------
chain_ddl=""
for migration in "${chain_migrations[@]}"; do
  if [ -r "${migration}" ]; then
    chain_ddl+="$(sql_without_comments "${migration}")"$'\n'
  fi
done
if [ -z "${chain_ddl}" ]; then
  fail "could not read any migrations/*/migration.sql, so chain parity cannot be checked"
  exit 2
fi

for entry in "${required_objects[@]}"; do
  kind="${entry%%:*}"
  object="${entry#*:}"
  if grep -qE "$(ddl_pattern "${kind}" "${object}")" <<<"${chain_ddl}"; then
    ok "chain path creates ${kind} ${object}"
  else
    fail "no migrations/*/migration.sql creates ${kind} ${object}, but the bootstrap does: fresh and chain databases now differ"
  fi
done

guarded_columns() {
  # Column names referenced as NEW."<col>" inside the immutability function of
  # the given file, sorted so the comparison is order-independent.
  awk '/CREATE OR REPLACE FUNCTION "enforce_design_revision_immutability"/,/\$\$;/' "$1" \
    | grep -o 'NEW\."[A-Za-z_]*"' \
    | sed 's/^NEW\.//; s/"//g' \
    | sort -u
}

asset_columns="$(guarded_columns "${asset}")"
reference_columns="$(guarded_columns "${reference_migration}")"

if [ -z "${asset_columns}" ]; then
  fail "could not read the guarded column list out of the bootstrap asset"
  exit 2
fi
if [ -z "${reference_columns}" ]; then
  fail "could not read the guarded column list out of the reference migration"
  exit 2
fi

if [ "${asset_columns}" = "${reference_columns}" ]; then
  ok "immutability function guards the same $(echo "${asset_columns}" | wc -l | tr -d ' ') columns as the chain path"
else
  fail "the bootstrap and the chain path guard different columns."
  echo "      only in bootstrap : $(comm -23 <(echo "${asset_columns}") <(echo "${reference_columns}") | tr '\n' ' ')"
  echo "      only in migration: $(comm -13 <(echo "${asset_columns}") <(echo "${reference_columns}") | tr '\n' ' ')"
fi

# The index objects are compared by their FULL DDL, not by their name.
#
# Name-anchored parity is not parity. `ddl_pattern` matches
# `CREATE UNIQUE INDEX ... "<name>"` anywhere in the statement, so the two
# copies of `product_credential_active_repository_unique` could disagree about
# everything that matters — the table, the key column, the WHERE predicate — and
# this check would still have reported them as agreeing. That is exactly the
# failure the predicate at `schema_bootstrap.sql` and its migration counterpart
# is written to prevent, so the guard must be able to see it.
#
# Two normalisations, and only two:
#   * whitespace collapsed, so line wrapping is not a difference;
#   * the `IF NOT EXISTS` idempotence clause removed, because the bootstrap
#     asset must be re-runnable (its IDEMPOTENCE CONTRACT) and the chain path
#     must not fail where the bootstrap already ran. That clause is the ONLY
#     permitted difference, and it is permitted deliberately.
# Everything else — table, key column, `WHERE` predicate — must match.
#
# The triggers are deliberately NOT compared this way: the asset wraps each in
# `DROP TRIGGER IF EXISTS` + `CREATE` so re-running it is a no-op, and the
# migration does not. For those, the guarded-column comparison above is what is
# actually enforced, and `tool/schema_bootstrap.sql` says so.
ddl_statement() {
  local name="$1" file="$2"
  sql_without_comments "${file}" \
    | tr '\n' ' ' \
    | grep -oE "CREATE[^;]*\"${name}\"[^;]*" \
    | head -1 \
    | sed -e 's/[[:space:]][[:space:]]*/ /g' -e 's/^ //' -e 's/ *$//' \
          -e 's/CREATE UNIQUE INDEX IF NOT EXISTS/CREATE UNIQUE INDEX/'
}

for entry in "${required_objects[@]}"; do
  kind="${entry%%:*}"
  object="${entry#*:}"
  [ "${kind}" = "index" ] || continue

  declaring=""
  for migration in "${chain_migrations[@]}"; do
    if [ -r "${migration}" ] \
      && grep -qE "$(ddl_pattern "${kind}" "${object}")" \
        <<<"$(sql_without_comments "${migration}")"; then
      declaring="${migration}"
      break
    fi
  done
  if [ -z "${declaring}" ]; then
    fail "no migrations/*/migration.sql declares ${kind} ${object}, so its DDL cannot be compared"
    continue
  fi

  asset_ddl_for_object="$(ddl_statement "${object}" "${asset}")"
  chain_ddl_for_object="$(ddl_statement "${object}" "${declaring}")"
  if [ -z "${asset_ddl_for_object}" ] || [ -z "${chain_ddl_for_object}" ]; then
    fail "could not read the DDL of ${object} out of the bootstrap asset or ${declaring}"
  elif [ "${asset_ddl_for_object}" = "${chain_ddl_for_object}" ]; then
    ok "${kind} ${object} declares byte-identical DDL in both homes (${declaring#"${server_dir}/"})"
  else
    fail "${kind} ${object} differs between the bootstrap asset and ${declaring#"${server_dir}/"}; a fresh and a chain-migrated database would enforce different things"
    echo "      bootstrap: ${asset_ddl_for_object}"
    echo "      chain    : ${chain_ddl_for_object}"
  fi
done

# ---------------------------------------------------------------------------
# 4. No generated definition.sql may be relied on to supply these objects. If a
#    hand edit were added to one it would be silently erased by the next
#    `serverpod create-migration`, which is how these objects came to exist on
#    the chain path only.
# ---------------------------------------------------------------------------
# The object NAMES are taken from `required_objects` above, not written out
# again here. A hand-maintained second list is exactly how the
# one-active-credential index came to be missing from this check while every
# other check covered it: adding an object to `required_objects` is enough, and
# nothing has to be remembered in two places.
hand_maintained_names="$(
  printf '%s\n' "${required_objects[@]}" | sed 's/^[^:]*://' | paste -sd'|' -
)"

offenders="$(grep -lE "${hand_maintained_names}" \
  "${server_dir}"/migrations/*/definition.sql 2>/dev/null || true)"
if [ -n "${offenders}" ]; then
  fail "these generated definition.sql files mention the hand-maintained objects:"
  echo "${offenders}" | sed 's/^/      /'
  echo "      A hand edit there is erased by the next regeneration. Put the DDL in"
  echo "      tool/schema_bootstrap.sql instead."
else
  ok "no generated definition.sql claims these objects; the bootstrap is their only source"
fi

# ---------------------------------------------------------------------------
# 5. Both wiring sites exist. A guard that passes while nothing applies the
#    bootstrap is worse than no guard, because it reads as coverage.
#
#    Matched as a RECIPE LINE, not as a bare substring: a mention inside a
#    comment satisfies a substring search while leaving the database
#    unenforced, which is exactly the silent pass this guard exists to stop.
# ---------------------------------------------------------------------------
if [ -r "${ci_workflow}" ] \
  && grep -qE '^[[:space:]]*dart run tool/schema_bootstrap\.dart' "${ci_workflow}"; then
  ok "CI applies the bootstrap (.github/workflows/integration.yaml)"
else
  fail "CI never runs tool/schema_bootstrap.dart; every fresh CI database stays unenforced"
fi

if [ -r "${makefile}" ] \
  && grep -qE '^[[:space:]]*dart run tool/schema_bootstrap\.dart' "${makefile}"; then
  ok "the local test path applies the bootstrap (Makefile)"
else
  fail "the local test path never runs tool/schema_bootstrap.dart; a local fresh database stays unenforced"
fi

# ---------------------------------------------------------------------------
if [ "${status}" -ne 0 ]; then
  echo ""
  echo "SCHEMA BOOTSTRAP GUARD FAILED. Fresh and chain-migrated databases no longer agree on:"
  echo "  - the design_revision immutability trigger,"
  echo "  - the design_review_result independence trigger,"
  echo "  - the one-approved-revision-per-work-item index,"
  echo "  - the one-active-credential-per-repository index."
  echo "Fix apps/server/tool/schema_bootstrap.sql and its migration counterpart together;"
  echo "never add the DDL to a generated definition.sql."
fi
exit "${status}"
