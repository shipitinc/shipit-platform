#!/usr/bin/env bash
#
# Negative controls for `../verify_schema_bootstrap.sh`.
#
# WHY THIS EXISTS. A guard that only ever runs on correct inputs is
# indistinguishable, from the outside, from a guard that cannot fail. The
# full-DDL parity check in that script was exercised only by its own pass: the
# `IF NOT EXISTS` divergence it normalised away could be injected in BOTH
# directions and the guard still exited 0, while no test anywhere replays the
# migration chain onto a bootstrapped database (see the script's header). So the
# guard was the only possible detector and it had never been shown to detect.
#
# WHAT IT DOES. For each case it builds a THROWAWAY FIXTURE — a minimal but
# faithful copy of everything the guard reads — applies one mutation, runs the
# guard against the fixture, and asserts the exit code. A positive control runs
# first: an unmutated fixture must produce the same 20 `OK:` / 0 `FAIL:` / exit 0
# as the real repository. Without it, every case below could "pass" against a
# fixture that was never checking anything in the first place.
#
# IT NEVER TOUCHES THE REPOSITORY. Every case runs in a `mktemp -d` directory
# and every file it reads from the repository is only ever READ. A negative
# control that mutated `tool/schema_bootstrap.sql` or a real migration would
# destroy the very evidence it verifies — and would leave the tree lying about
# what it contains. That claim is not left to trust: the run checksums every
# repository file it reads, before and after, and FAILS if any of them changed.
#
# NOT WIRED INTO CI. `../verify_schema_bootstrap.sh` is, in
# `.github/workflows/ci.yaml` job `schema-guard`; this harness is NOT, because
# wiring it in was outside the change that added the expectation. Until someone
# does, these controls exist and are green locally, and CI will not catch their
# own regression. Tracked as a follow-up.
#
# Run: apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh
# Exit: 0 every case behaved as declared, 1 at least one did not, 2 the harness
# itself could not run. Requires only bash and the POSIX tools the guard already
# uses; no bats, no network, no database, no Docker.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_dir="$(cd "${here}/.." && pwd)"
server_dir="$(cd "${here}/../.." && pwd)"
repo_root="$(cd "${here}/../../../.." && pwd)"
guard="${tool_dir}/verify_schema_bootstrap.sh"

for required in "${guard}" "${tool_dir}/schema_bootstrap.sql" \
  "${tool_dir}/schema_bootstrap.dart" "${repo_root}/Makefile"; do
  if [ ! -r "${required}" ]; then
    echo "FAIL: cannot run the harness, missing or unreadable: ${required}"
    exit 2
  fi
done

work="$(mktemp -d "${TMPDIR:-/tmp}/verify_schema_bootstrap_controls.XXXXXXXX")" || {
  echo "FAIL: cannot create a temporary fixture directory"
  exit 2
}

# Absolute paths only — the recipe below `cd`s into a fixture, and a relative
# cleanup trap that runs after that `cd` is a cleanup trap that deletes nothing.
cleanup() {
  if [ -n "${work}" ] && [ -d "${work}" ]; then
    if ! rm -rf "${work}"; then
      echo "CLEANUP FAILED: could not remove the temporary fixtures at ${work}" >&2
      echo "              finish the job with: rm -rf '${work}'" >&2
    fi
  fi
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

checksum_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    sha256sum "$1" | cut -d' ' -f1
  fi
}

# Everything the harness reads out of the repository, by content. Read-only by
# construction: there is no write to any path under `${repo_root}` in this file.
repo_fingerprint() {
  local file
  {
    find "${server_dir}/tool" "${server_dir}/migrations" -type f
    printf '%s\n' "${repo_root}/Makefile" \
      "${repo_root}/.github/workflows/integration.yaml"
  } | LC_ALL=C sort | while IFS= read -r file; do
    printf '%s  %s\n' "$(checksum_of "${file}")" "${file#"${repo_root}/"}"
  done
}

repo_fingerprint >"${work}/before.fingerprint"

# The fixture is a copy of the guard's real inputs, so a case exercises the same
# code paths the CI wiring does. `cp -R` of `migrations/` brings the generated
# `definition.sql` files with it, which check 4 needs in order to be able to
# fail.
build_fixture() {
  local dest="$1"
  mkdir -p "${dest}/apps/server/tool" "${dest}/.github/workflows" \
    || return 1
  cp "${guard}" "${tool_dir}/schema_bootstrap.sql" \
    "${tool_dir}/schema_bootstrap.dart" "${dest}/apps/server/tool/" || return 1
  cp -R "${server_dir}/migrations" "${dest}/apps/server/" || return 1
  cp "${repo_root}/Makefile" "${dest}/Makefile" || return 1
  cp "${repo_root}/.github/workflows/integration.yaml" \
    "${dest}/.github/workflows/integration.yaml" || return 1
}

# Rewrite the first line containing <literal> to <replacement>, in a fixture copy.
# Deliberately NOT `sed -i`: BSD and GNU sed disagree about whether `-i` takes an
# argument, and a control that only runs on one of them is not a control. The
# match is a literal substring, not a regex, so no index name needs escaping.
replace_line() {
  local file="$1" literal="$2" replacement="$3" tmp
  tmp="$(mktemp "${work}/replace.XXXXXXXX")" || return 1
  if ! awk -v lit="${literal}" -v rep="${replacement}" '
        !done && index($0, lit) > 0 { $0 = rep; done = 1 }
        { print }
      ' "${file}" >"${tmp}"; then
    rm -f "${tmp}"
    return 1
  fi
  if cmp -s "${tmp}" "${file}"; then
    echo "     (mutation target not found: ${literal})" >&2
    rm -f "${tmp}"
    return 1
  fi
  mv "${tmp}" "${file}"
}

total=0
failed=0

run_case() {
  local name="$1" expected="$2" mutate="$3" expect_ok_lines="${4:-}"
  local dir="${work}/case-${name}" output actual ok_lines fail_lines
  total=$((total + 1))

  if ! build_fixture "${dir}"; then
    echo "FAIL ${name}: could not build the fixture"
    failed=$((failed + 1))
    return
  fi
  if [ -n "${mutate}" ] && ! "${mutate}" "${dir}"; then
    echo "FAIL ${name}: the mutation itself failed, so the case proved nothing"
    failed=$((failed + 1))
    return
  fi

  output="$(bash "${dir}/apps/server/tool/verify_schema_bootstrap.sh" 2>&1)"
  actual="${?}"
  ok_lines="$(printf '%s\n' "${output}" | grep -c '^OK:' || true)"
  fail_lines="$(printf '%s\n' "${output}" | grep -c '^FAIL:' || true)"

  if [ "${actual}" != "${expected}" ]; then
    failed=$((failed + 1))
    echo "FAIL ${name}: expected exit ${expected}, got ${actual}" \
      "(${ok_lines} OK, ${fail_lines} FAIL)"
    printf '%s\n' "${output}" | sed 's/^/     | /'
    return
  fi
  if [ -n "${expect_ok_lines}" ] && [ "${ok_lines}" != "${expect_ok_lines}" ]; then
    failed=$((failed + 1))
    echo "FAIL ${name}: expected ${expect_ok_lines} OK lines, got ${ok_lines}" \
      "(${fail_lines} FAIL)"
    printf '%s\n' "${output}" | sed 's/^/     | /'
    return
  fi
  echo "ok   ${name}: exit ${actual}, ${ok_lines} OK, ${fail_lines} FAIL"
}

credential_index='CREATE UNIQUE INDEX IF NOT EXISTS "product_credential_active_repository_unique"'
credential_index_no_clause='CREATE UNIQUE INDEX "product_credential_active_repository_unique"'

# --- positive control -------------------------------------------------------
# An unmutated fixture must behave exactly like the real repository. If this
# fails, every case below is meaningless, so it is asserted separately.
run_case baseline 0 '' 20

# --- the four negative controls the correction is required to carry ----------

# 1. The clause leaves the CREDENTIAL index's migration. That migration's own
#    comment says the clause is what makes a replay onto an already-bootstrapped
#    database a no-op rather than an error; without it the chain path fails on
#    exactly the database it was written to survive. Exited 0 before the fix.
mutate_drop_clause_migration() {
  replace_line "$1/apps/server/migrations/20261006150645000/migration.sql" \
    "${credential_index}" "${credential_index_no_clause}"
}
run_case drop-clause-from-migration 1 mutate_drop_clause_migration

# 2. The clause leaves the BOOTSTRAP ASSET, so re-running it against a
#    chain-migrated database stops being a no-op — the asset's own IDEMPOTENCE
#    CONTRACT. Also exited 0 before the fix: the two homes agreed with each
#    other, which is what the old comparison actually compared.
mutate_drop_clause_asset() {
  replace_line "$1/apps/server/tool/schema_bootstrap.sql" \
    "${credential_index}" "${credential_index_no_clause}"
}
run_case drop-clause-from-asset 1 mutate_drop_clause_asset

# 3. The clause is ADDED to `20260920232118956`, where `asset-only` is declared.
#    The clause-stripped DDL comparison cannot see this at all — both homes
#    become identical — so only the declared expectation catches it. This is the
#    control that proves the new comparison is live and not merely present.
mutate_add_clause_older_migration() {
  replace_line "$1/apps/server/migrations/20260920232118956/migration.sql" \
    'CREATE UNIQUE INDEX "design_revision_approved_unique_per_work_item"' \
    'CREATE UNIQUE INDEX IF NOT EXISTS "design_revision_approved_unique_per_work_item"'
}
run_case add-clause-where-asset-only-declared 1 mutate_add_clause_older_migration

# 4. A hand-maintained index name appears in a generated definition.sql — the
#    thing check 4 exists to catch, and the regression an entry gaining a third
#    field was capable of causing: `sed 's/^[^:]*://'` would have left
#    `..._unique:both` in the pattern, matched nothing, and check 4 would have
#    passed silently. Now that names are derived with `cut -d: -f2` it still
#    exits 1.
mutate_plant_index_in_definition() {
  printf '\nCREATE UNIQUE INDEX IF NOT EXISTS "product_credential_active_repository_unique"\n' \
    >>"$1/apps/server/migrations/20261006150645000/definition.sql"
}
run_case plant-index-in-definition 1 mutate_plant_index_in_definition

# --- the new fail-closed path ------------------------------------------------
# An index entry that does not declare what the clause should be is the guard
# being unable to judge, which is exit 2 — never a fall back to the forgiving
# behaviour that caused this finding.

mutate_drop_expectation_field() {
  replace_line "$1/apps/server/tool/verify_schema_bootstrap.sh" \
    '"index:product_credential_active_repository_unique:both"' \
    '"index:product_credential_active_repository_unique"'
}
run_case index-entry-without-expectation 2 mutate_drop_expectation_field

mutate_misspell_expectation() {
  replace_line "$1/apps/server/tool/verify_schema_bootstrap.sh" \
    '"index:product_credential_active_repository_unique:both"' \
    '"index:product_credential_active_repository_unique:btoh"'
}
run_case index-entry-with-unrecognised-expectation 2 mutate_misspell_expectation

# --- positive controls: the pre-existing DDL comparison still works ----------
# These prove the refactor did not weaken the clause-stripped comparison into
# something vacuous. Each changes a real difference the old check caught.

mutate_drift_where_predicate() {
  replace_line "$1/apps/server/migrations/20261006150645000/migration.sql" \
    "    WHERE (\"status\" <> 'revoked');" "    WHERE (\"status\" <> 'active');"
}
run_case drift-in-where-predicate 1 mutate_drift_where_predicate

mutate_drift_key_column() {
  replace_line "$1/apps/server/migrations/20261006150645000/migration.sql" \
    '    ON "product_credential" USING btree ("repositoryId")' \
    '    ON "product_credential" USING btree ("credentialId")'
}
run_case drift-in-key-column 1 mutate_drift_key_column

mutate_drift_table() {
  replace_line "$1/apps/server/migrations/20261006150645000/migration.sql" \
    '    ON "product_credential" USING btree ("repositoryId")' \
    '    ON "product_credential_legacy" USING btree ("repositoryId")'
}
run_case drift-in-table 1 mutate_drift_table

# In the ASSET home, and on the SECOND object, so it exercises the direction the
# three above do not: those all diverge the chain home, this diverges the
# bootstrap home of the other index.
mutate_drift_where_predicate_in_asset() {
  replace_line "$1/apps/server/tool/schema_bootstrap.sql" \
    "    WHERE (\"status\" = 'approved');" "    WHERE (\"status\" = 'accepted');"
}
run_case drift-in-where-predicate-of-asset 1 mutate_drift_where_predicate_in_asset

# --- the repository must be exactly as it was --------------------------------
repo_fingerprint >"${work}/after.fingerprint"
if ! diff -u "${work}/before.fingerprint" "${work}/after.fingerprint" >"${work}/drift" 2>&1; then
  failed=$((failed + 1))
  echo "FAIL repository-untouched: a file this harness reads CHANGED during the run."
  echo "     Every case is supposed to run in a temporary fixture. The diff:"
  sed 's/^/     /' "${work}/drift"
  echo "     Restore these before trusting anything above."
else
  total=$((total + 1))
  echo "ok   repository-untouched: every file this harness reads is byte-identical"
fi

echo ""
echo "${total} cases, ${failed} failed."
if [ "${failed}" -ne 0 ]; then
  exit 1
fi
echo "NOTE: these controls are NOT yet wired into CI. They are green here; nothing"
echo "      runs them on every push. That is a named follow-up, not a pass."
exit 0