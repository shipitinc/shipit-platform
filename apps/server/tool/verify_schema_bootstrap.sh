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
# THE IDEMPOTENCE CLAUSE IS NOT EXEMPT — IT IS DECLARED. A full-DDL comparison has
# one divergence it cannot judge on its own: `IF NOT EXISTS`. It is genuinely
# optional for one index (the asset must be re-runnable; an older migration has no
# reason to be) and MANDATORY for the other, because a chain migration replayed
# onto an already-bootstrapped database must be a no-op rather than an error. A
# blanket normalisation cannot tell those apart: normalising the clause away
# forgives it on BOTH objects, so dropping it from the credential index — the one
# divergence that breaks the chain path — passed at exit 0. So the clause is
# stripped from the DDL comparison and then compared SEPARATELY against an
# expectation that each index entry states for itself. An absent or unrecognised
# expectation is exit 2, never the forgiving default.
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
#
# An INDEX entry carries a third field: the `IF NOT EXISTS` idempotence clause it
# declares for itself — `both` (both homes must carry it) or `asset-only` (the
# bootstrap asset must, the migration must not). It is part of THIS entry on
# purpose. A second table of per-object expectations would reintroduce exactly
# the two-places bookkeeping this script exists to prevent, and the temptation to
# maintain it is why the divergence below could hide in the first place.
#
# `design_revision_approved_unique_per_work_item:asset-only` IS A DECLARED
# ASYMMETRY, NOT A VERIFIED ONE. `20261006150645000` states in its own comment why
# its clause is mandatory; `20260920232118956` gives no such rationale, and is the
# older migration. If the credential index's clause is required for
# chain-replay-onto-bootstrapped safety, this one is plausibly missing it too —
# a pre-existing latent defect, out of scope for the change that added this
# check. Writing the expectation down forces a human to look at it; it does not
# settle it. See the tracked follow-up, and do not "fix" the SQL without deciding
# whether `20260920232118956` may still be rewritten at all.
required_objects=(
  "trigger:trigger_design_revision_immutability"
  "trigger:trigger_design_review_independence"
  "index:design_revision_approved_unique_per_work_item:asset-only"
  "index:product_credential_active_repository_unique:both"
)

# The expectation is load-bearing, so an absent or unrecognised one means the
# guard cannot judge — the same class as a missing input file, and the same exit
# code. It must never fall back to tolerating the clause: that fallback IS the
# defect this check was added to close.
expectation_error() {
  local headline="$1"
  shift
  local line
  echo "FAIL: cannot run the guard, ${headline}"
  for line in "$@"; do
    echo "      ${line}"
  done
  exit 2
}

# Parse and validate every entry ONCE, up front, before any check can report a
# pass. `checked_objects` is `required_objects` reduced to the `kind:name` the
# existing checks match on; `clause_expectations` carries the third field in
# step. Checks 1-4 read from these, so no check can re-derive a name by stripping
# a fixed number of fields and get it wrong after an entry gains one.
checked_objects=()
clause_expectations=()

for entry in "${required_objects[@]}"; do
  kind="${entry%%:*}"
  rest="${entry#*:}"
  name="${rest%%:*}"
  expectation=""
  # `${name}` equals `${rest}` exactly when the entry carries no second colon, so
  # an empty `${expectation}` with a differing `${rest}` is a trailing colon
  # (`index:name:`) — still an absent expectation, never a permissive one.
  has_expectation_field=0
  if [ "${name}" != "${rest}" ]; then
    expectation="${rest#*:}"
    has_expectation_field=1
  fi

  case "${kind}" in
    index)
      if [ -z "${name}" ]; then
        expectation_error \
          "index entry '${entry}' has no name." \
          "An index entry is kind:name:expectation."
      fi
      # Unrecognised, absent, or carrying a further colon — all the same thing:
      # this check cannot say what the clause should be, so it must not guess.
      case "${expectation}" in
        both) ;;
        asset-only) ;;
        *)
          expectation_error \
            "index entry '${entry}' does not declare a usable idempotence expectation." \
            "Every index entry must end in :both or :asset-only. Declaring it is what" \
            "replaces the clause normalisation that forgave the credential index's" \
            "IF NOT EXISTS dropping out of its migration."
          ;;
      esac
      ;;
    trigger)
      if [ -z "${name}" ]; then
        echo "FAIL: cannot run the guard, trigger entry '${entry}' has no name."
        exit 2
      fi
      if [ "${has_expectation_field}" -eq 1 ]; then
        expectation_error \
          "trigger entry '${entry}' declares an idempotence expectation." \
          "Triggers are deliberately NOT compared by full DDL (the asset wraps" \
          "each in DROP+CREATE so re-running it is a no-op), so there is nothing" \
          "for an expectation to be compared against."
      fi
      ;;
    *)
      expectation_error \
        "required_objects entry '${entry}' has unknown kind '${kind}'." \
        "This guard knows how to check index and trigger objects only; an" \
        "unrecognised kind would skip checks 3 and 4 without saying so."
      ;;
  esac

  checked_objects+=("${kind}:${name}")
  clause_expectations+=("${expectation}")
done

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
for entry in "${checked_objects[@]}"; do
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
for entry in "${checked_objects[@]}"; do
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

for entry in "${checked_objects[@]}"; do
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
#   * the `IF NOT EXISTS` idempotence clause removed, so the remaining DDL can be
#     compared for everything it CAN speak about.
# Everything else — table, key column, `WHERE` predicate — must match.
#
# Removing the clause is not a licence for it to differ, and this comment used to
# read as if it were. It is why the clause cannot be judged by the comparison
# above: the asset must be re-runnable (its IDEMPOTENCE CONTRACT) while an older
# migration has no such duty, so the two legitimately differ; but
# `20261006150645000` says in its own comment that ITS clause is what makes a
# replay onto an already-bootstrapped database a no-op instead of an error. A
# blanket normalisation forgives it on both objects, and deleting it from the
# credential index's migration exited 0. So the clause is judged separately,
# below, against the expectation its own `required_objects` entry declares.
#
# The triggers are deliberately NOT compared this way: the asset wraps each in
# `DROP TRIGGER IF EXISTS` + `CREATE` so re-running it is a no-op, and the
# migration does not. For those, the guarded-column comparison above is what is
# actually enforced, and `tool/schema_bootstrap.sql` says so.
ddl_statement_raw() {
  local name="$1" file="$2"
  sql_without_comments "${file}" \
    | tr '\n' ' ' \
    | grep -oE "CREATE[^;]*\"${name}\"[^;]*" \
    | head -1 \
    | sed -e 's/[[:space:]][[:space:]]*/ /g' -e 's/^ //' -e 's/ *$//'
}

# The clause-stripped statement: identical to what this check compared before the
# expectation existed, so table / key / `WHERE` / `UNIQUE` parity is unchanged.
ddl_statement() {
  ddl_statement_raw "$1" "$2" \
    | sed 's/CREATE UNIQUE INDEX IF NOT EXISTS/CREATE UNIQUE INDEX/'
}

# Whether <name>'s DDL in <file> carries the `IF NOT EXISTS` idempotence clause,
# as `yes` / `no`, or empty when the statement itself could not be read. Empty is
# deliberately not `no`: "the guard could not read it" and "the clause is absent"
# are different findings and must not be reported as the same one.
#
# Matched through a herestring for the reason given on `sql_without_comments`.
clause_presence() {
  local statement
  statement="$(ddl_statement_raw "$1" "$2")"
  if [ -z "${statement}" ]; then
    printf ''
  elif grep -qE 'CREATE[[:space:]]+UNIQUE[[:space:]]+INDEX[[:space:]]+IF[[:space:]]+NOT[[:space:]]+EXISTS' \
    <<<"${statement}"; then
    printf 'yes'
  else
    printf 'no'
  fi
}

for entry_index in "${!checked_objects[@]}"; do
  entry="${checked_objects[${entry_index}]}"
  kind="${entry%%:*}"
  object="${entry#*:}"
  expectation="${clause_expectations[${entry_index}]}"
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

  # Second comparison, in a direction the clause-stripped one cannot see: the
  # clause itself, per home, against what this object declared for itself. Same
  # code for every object — the per-object fact is data in `required_objects`, not
  # a branch in here.
  asset_clause="$(clause_presence "${object}" "${asset}")"
  chain_clause="$(clause_presence "${object}" "${declaring}")"

  case "${expectation}" in
    both)         expected_asset_clause="yes"; expected_chain_clause="yes" ;;
    asset-only)   expected_asset_clause="yes"; expected_chain_clause="no" ;;
    *)
      # Unreachable: the parse pass above exits 2 on anything else.
      expectation_error "index ${object} has unrecognised expectation '${expectation}'"
      ;;
  esac

  if [ -z "${asset_clause}" ] || [ -z "${chain_clause}" ]; then
    fail "could not read the IF NOT EXISTS idempotence clause of ${object} out of the bootstrap asset or ${declaring}"
  elif [ "${asset_clause}" = "${expected_asset_clause}" ] \
    && [ "${chain_clause}" = "${expected_chain_clause}" ]; then
    ok "${kind} ${object}: IF NOT EXISTS is ${expectation} as declared (bootstrap ${asset_clause}, chain ${chain_clause})"
  else
    fail "${kind} ${object}: IF NOT EXISTS is ${expectation} as declared, but the bootstrap carries ${asset_clause:-<unreadable>} and ${declaring#"${server_dir}/"} carries ${chain_clause:-<unreadable>}; the divergence the clause was normalised away for is exactly the one that decides whether a chain migration replayed onto a bootstrapped database is a no-op or an error"
    echo "      expected: bootstrap ${expected_asset_clause}, chain ${expected_chain_clause}"
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
#
# `cut -d: -f2`, NOT `sed 's/^[^:]*://'`. An index entry gained a third field (its
# idempotence expectation), and a sed that strips exactly one field would have
# left `product_credential_active_repository_unique:both` in the pattern below —
# which matches no definition.sql, so `offenders` came back empty and this check
# SILENTLY PASSED with the object planted in a generated definition.sql. Deriving
# the name by position rather than by "strip the prefix" makes the entry's arity
# unable to leak into the regex, in this check and in every future one.
hand_maintained_names="$(
  printf '%s\n' "${required_objects[@]}" | cut -d: -f2 | paste -sd'|' -
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
