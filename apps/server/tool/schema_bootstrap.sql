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
--   That is exactly how the objects below came to exist in
--   `migrations/20260920232118956/migration.sql` only, and in no
--   `definition.sql` at all.
--
--   So the hand-maintained content lives HERE, outside `migrations/`, where
--   regeneration cannot reach it, and is applied after Serverpod's own
--   migration step by `tool/schema_bootstrap.dart`. See that file for the
--   apply/verify contract and the wiring into CI and the local test path.
--
-- IDEMPOTENCE CONTRACT. Every statement is safe to re-run against a database
-- that already has these objects (chain-migrated, or a previous bootstrap
-- run): functions are CREATE OR REPLACE, the index is CREATE ... IF NOT
-- EXISTS, and each trigger is DROP ... IF EXISTS immediately followed by
-- CREATE. Running the file twice must be a no-op.
--
-- PARITY CONTRACT. The function bodies and the guarded column list below are
-- deliberately byte-identical to `migrations/20260920232118956/migration.sql`
-- so a bootstrapped (fresh) database enforces exactly what a chain-migrated
-- one enforces. Do not tighten or loosen the column list here without the same
-- change in that migration's semantics — an asymmetry here is a fresh-vs-chain
-- divergence, which is the defect this file exists to remove. In particular
-- `updatedAt` is NOT in the guarded list: that column is Serverpod-managed and
-- the chain path does not guard it either.
--
-- Adding a new hand-maintained object: append it here, append it to the
-- `_requiredObjects` list in `tool/schema_bootstrap.dart` so the applier fails
-- loudly if it does not take effect, and add a probe case.
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
