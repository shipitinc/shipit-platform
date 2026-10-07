-- ============================================================================
-- SCHEMA BOOTSTRAP — hand-maintained schema extensions the Serverpod
-- model-driven generator cannot express.
--
-- WHY THIS FILE EXISTS (do not "fix" this by editing a definition.sql).
--
--   Serverpod applies exactly ONE artifact when a database has no recorded
--   migration version: the LATEST `definition.sql`
--   (serverpod-3.4.13/lib/src/database/migrations/migration_manager.dart
--   `_loadMigrationSQL`, lines 194-205: when `fromVersion == null` it reads
--   `definitionSql` and returns that single entry; only the `else` branch
--   walks `migration.sql` files). A database that has been chain-migrated
--   replays `migration.sql` instead and therefore DOES get every hand-written
--   object ever written into one.
--
--   The two paths therefore diverge for anything the generator cannot render.
--   Serverpod's generator rebuilds `definition.sql` verbatim from the Dart
--   models on every `serverpod create-migration`
--   (serverpod_cli-3.4.13/lib/src/migrations/generator.dart:543-581,
--   `definitionSqlFile.writeAsString(definitionSql)`), so a hand edit to a
--   generated `definition.sql` is silently erased by the next regeneration.
--   That is exactly how the objects below came to exist in a
--   `migrations/*/migration.sql` only, and in no `definition.sql` at all:
--   `20260920232118956` carries the two triggers and the approved-revision
--   index, `20261006150645000` carries the active-credential index.
--
--   So the hand-maintained content lives HERE, outside `migrations/`, where
--   regeneration cannot reach it, and is applied after Serverpod's own
--   migration step by `tool/schema_bootstrap.dart`. See that file for the
--   apply/verify contract and the wiring into CI and the local test path.
--
--   Every object below therefore has TWO homes, and both are required. This
--   file covers the fresh path (no recorded migration version -> Serverpod
--   applies `definition.sql`, which cannot carry any of them). The `migration.sql`
--   counterpart covers the chain path, which is the one a deployed database
--   takes. `tool/verify_schema_bootstrap.sh` fails if the two disagree.
--
-- IDEMPOTENCE CONTRACT. Every statement is safe to re-run against a database
-- that already has these objects (chain-migrated, or a previous bootstrap
-- run): functions are CREATE OR REPLACE, the indexes are CREATE ... IF NOT
-- EXISTS, and each trigger is DROP ... IF EXISTS immediately followed by
-- CREATE. Running the file twice must be a no-op.
--
-- PARITY CONTRACT. Every object below must ALSO be created by some
-- `migrations/*/migration.sql`, so a bootstrapped (fresh) database enforces
-- exactly what a chain-migrated one enforces.
--
-- WHAT IS ENFORCED, PRECISELY, so this paragraph is not a claim the guard
-- cannot back up:
--   * the two indexes are compared by their FULL DDL — same table, same key
--     column, same WHERE predicate — against the migration that declares each.
--     That is what `tool/verify_schema_bootstrap.sh` check 3 asserts, and it is
--     what makes the byte-identical statement below true. The only permitted
--     difference is the `IF NOT EXISTS` idempotence clause, which this file
--     needs and the chain path does not.
--   * the immutability function is compared by its GUARDED COLUMN LIST only.
--     Its body is not compared, because the asset wraps it in
--     `DROP TRIGGER IF EXISTS` + `CREATE` so re-running this file is a no-op
--     while the migration is not — that difference is required by the
--     IDEMPOTENCE CONTRACT above, so a body comparison would have to normalise
--     it, and a normalised comparison of a trigger body is worth less than the
--     column list it is really about.
--
-- Do not change an object here without the same change in its migration
-- counterpart — an asymmetry is a fresh-vs-chain divergence, which is the defect
-- this file exists to remove. In particular `updatedAt` is NOT in the guarded
-- list: that column is Serverpod-managed and the chain path does not guard it
-- either.
--
-- Adding a new hand-maintained object: append it here, add the matching
-- `CREATE` to a NEW `migrations/<version>/migration.sql` (never to an existing
-- `definition.sql`, and never to a `migration.sql` that has already shipped),
-- append it to the `_requiredObjects` list in `tool/schema_bootstrap.dart` so
-- the applier fails loudly if it does not take effect, add it to
-- `required_objects` in `tool/verify_schema_bootstrap.sh`, and add a probe
-- case.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- design_revision_approved_unique_per_work_item
-- Partial unique index: at most one 'approved' revision per work item. This is
-- what makes approval exclusive under concurrency; a second approved revision
-- for the same work item is a database error, not a read-modify-write race.
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS "design_revision_approved_unique_per_work_item"
    ON "design_revision" USING btree ("workItemId")
    WHERE ("status" = 'approved');

-- ---------------------------------------------------------------------------
-- product_credential_active_repository_unique
-- Partial unique index: at most one NON-REVOKED credential per repository. This
-- is what makes "one active credential per repository" exclusive under
-- concurrency; a second active credential for the same repository is a database
-- error, not a read-modify-write race.
--
-- The predicate is deliberately byte-identical to the read that defines
-- "active" in `PostgresProductRegistryStore.readActiveCredentialForRepository`
-- (`WHERE "repositoryId" = @repositoryId AND "status" <> 'revoked'`). A
-- constraint whose predicate is wider than the query that relies on it would
-- refuse rows the application considers legal; narrower would let two rows the
-- application treats as one through. Keeping them identical is what makes
-- rotation work: `rotateCredential` revokes the old credential FIRST, and a
-- revoked row is excluded from this index, so a replacement may be inserted.
--
-- Note this narrows nothing that previously succeeded in a single-threaded
-- caller: `ProductRegistryEngine.recordGeneratedCredential` already refuses a
-- second active credential for a repository before it writes. What the index
-- adds is the guarantee that two callers cannot both pass that read first.
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS "product_credential_active_repository_unique"
    ON "product_credential" USING btree ("repositoryId")
    WHERE ("status" <> 'revoked');

-- ---------------------------------------------------------------------------
-- trigger_design_revision_immutability
-- Rejects any change to an approved revision's content columns. An approved
-- design revision is an audit record: once approved it may only be superseded
-- by a new revision, never edited in place.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "enforce_design_revision_immutability"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD."status" = 'approved' AND (
      NEW."revisionId" IS DISTINCT FROM OLD."revisionId" OR
      NEW."workItemId" IS DISTINCT FROM OLD."workItemId" OR
      NEW."productId" IS DISTINCT FROM OLD."productId" OR
      NEW."parentRevisionId" IS DISTINCT FROM OLD."parentRevisionId" OR
      NEW."designSystemRevision" IS DISTINCT FROM OLD."designSystemRevision" OR
      NEW."providerType" IS DISTINCT FROM OLD."providerType" OR
      NEW."penpotFileId" IS DISTINCT FROM OLD."penpotFileId" OR
      NEW."penpotPageId" IS DISTINCT FROM OLD."penpotPageId" OR
      NEW."boardIdsJson" IS DISTINCT FROM OLD."boardIdsJson" OR
      NEW."responsiveTargetsJson" IS DISTINCT FROM OLD."responsiveTargetsJson" OR
      NEW."statesRepresentedJson" IS DISTINCT FROM OLD."statesRepresentedJson" OR
      NEW."artifactRefsJson" IS DISTINCT FROM OLD."artifactRefsJson" OR
      NEW."designerExecutionId" IS DISTINCT FROM OLD."designerExecutionId" OR
      NEW."reviewExecutionIdsJson" IS DISTINCT FROM OLD."reviewExecutionIdsJson" OR
      NEW."riskTier" IS DISTINCT FROM OLD."riskTier" OR
      NEW."reviewScopeJson" IS DISTINCT FROM OLD."reviewScopeJson" OR
      NEW."carriedForwardFromRevisionId" IS DISTINCT FROM OLD."carriedForwardFromRevisionId" OR
      NEW."supersededByRevisionId" IS DISTINCT FROM OLD."supersededByRevisionId" OR
      NEW."createdAt" IS DISTINCT FROM OLD."createdAt" OR
      NEW."approvedAt" IS DISTINCT FROM OLD."approvedAt"
  ) THEN
    RAISE EXCEPTION 'Cannot modify approved design revision %', OLD."revisionId";
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS "trigger_design_revision_immutability" ON "design_revision";
CREATE TRIGGER "trigger_design_revision_immutability"
BEFORE UPDATE ON "design_revision"
FOR EACH ROW
EXECUTE FUNCTION "enforce_design_revision_immutability"();

-- ---------------------------------------------------------------------------
-- trigger_design_review_independence
-- Rejects a review result whose review execution is the execution that
-- produced the revision it is reviewing. Separation of duties is a database
-- invariant here, not a convention the call sites are trusted to honour.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "enforce_design_review_independence"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_designer_execution_id text;
BEGIN
  SELECT "designerExecutionId" INTO v_designer_execution_id
  FROM "design_revision"
  WHERE "revisionId" = NEW."revisionId";

  IF v_designer_execution_id IS NOT NULL AND NEW."reviewExecutionId" = v_designer_execution_id THEN
    RAISE EXCEPTION 'Review execution % cannot review its own design revision % (independence violation)', NEW."reviewExecutionId", NEW."revisionId";
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS "trigger_design_review_independence" ON "design_review_result";
CREATE TRIGGER "trigger_design_review_independence"
BEFORE INSERT ON "design_review_result"
FOR EACH ROW
EXECUTE FUNCTION "enforce_design_review_independence"();

COMMIT;
