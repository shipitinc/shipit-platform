BEGIN;

--
-- ACTION DROP TABLE
--
DROP TABLE "design_revision" CASCADE;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "design_revision" (
    "id" bigserial PRIMARY KEY,
    "revisionId" text NOT NULL,
    "workItemId" text NOT NULL,
    "productId" text NOT NULL,
    "parentRevisionId" text,
    "designSystemRevision" text NOT NULL,
    "providerType" text NOT NULL,
    "penpotFileId" text,
    "penpotPageId" text,
    "boardIdsJson" text NOT NULL,
    "responsiveTargetsJson" text NOT NULL,
    "statesRepresentedJson" text NOT NULL,
    "artifactRefsJson" text NOT NULL,
    "designerExecutionId" text NOT NULL,
    "reviewExecutionIdsJson" text NOT NULL,
    "fidelityAnchorSchemaVersion" text NOT NULL,
    "status" text NOT NULL,
    "riskTier" text NOT NULL,
    "reviewScopeJson" text,
    "carriedForwardFromRevisionId" text,
    "supersededByRevisionId" text,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL,
    "approvedAt" timestamp without time zone,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "design_revision_id_unique" ON "design_revision" USING btree ("revisionId");
CREATE INDEX "design_revision_work_item_idx" ON "design_revision" USING btree ("workItemId");
CREATE INDEX "design_revision_status_idx" ON "design_revision" USING btree ("status");
CREATE INDEX "design_revision_designer_execution_idx" ON "design_revision" USING btree ("designerExecutionId");

--
-- HAND-MAINTAINED OBJECTS RESTORED AFTER THE CASCADE.
--
-- WHY THIS BLOCK IS HERE, AND WHY A GENERATOR WILL NEVER PRODUCE IT. The four
-- index statements above are the COMPLETE set the generator emits for this
-- table, because they are the four the `.spy.yaml` models declare. Everything
-- below is enforced in hand-maintained DDL and has no model behind it, so
-- `serverpod create-migration` renders none of it. The `DROP TABLE ... CASCADE`
-- at the top of this file removed it from every database that replays the
-- chain. WITHOUT the block below, a chain-migrated database -- every developer
-- machine, QA and production -- ends this migration WITHOUT:
--
--   * design_revision_approved_unique_per_work_item -- the PARTIAL unique index
--     that makes "at most one approved revision per work item" exclusive under
--     concurrency, a database error rather than a read-modify-write race;
--   * trigger_design_revision_immutability -- the BEFORE UPDATE trigger that
--     makes an approved design revision an audit record which cannot be edited
--     in place.
--
-- NOTHING ELSE RECREATES EITHER OBJECT ON THE CHAIN PATH, and no gate in this
-- repository can see it missing:
--
--   * A FRESH database is built from the newest `definition.sql` and then has
--     `tool/schema_bootstrap.sql` applied, and no `migration.sql` is replayed
--     there at all -- so `make test-integration` and CI restore both objects by
--     a DIFFERENT path and prove nothing about this one.
--   * `tool/verify_schema_bootstrap.sh` builds its `chain_ddl` by CONCATENATING
--     every `migration.sql` and grepping the concatenation for the DDL. A `DROP`
--     does not remove `20260920232118956`'s text from that concatenation, so
--     every check in that script passes with this block deleted. A destructive
--     migration is invisible to a textual-presence check by construction.
--
-- PROVENANCE. The DDL below is REPRODUCED BYTE-FOR-BYTE from
-- `migrations/20260920232118956/migration.sql`, which is where these objects
-- were first created and which `verify_schema_bootstrap.sh` still reads as its
-- reference. It is duplicated here rather than moved because
-- `20260920232118956` HAS SHIPPED: editing it would rewrite history a database
-- that already recorded it never replays, and the database this file exists to
-- repair is exactly one that already recorded it.
--
-- ORDER IS LOAD-BEARING. All of it comes AFTER the `CREATE TABLE` above. The
-- index and the trigger both attach to the table the CASCADE removed, so any of
-- it placed before the CREATE would be refused against a table that does not
-- exist and would roll the whole migration back, taking the new column with it.
--
-- WHY THE FUNCTION IS RE-DECLARED RATHER THAN ASSUMED INTACT. `tool/
-- schema_bootstrap.sql` wraps this same function in CREATE OR REPLACE for the
-- same reason. A plpgsql function body is not a recorded dependency of the
-- tables it names, so whether `enforce_design_revision_immutability` outlived
-- the CASCADE is a property of the server's dependency tracking rather than
-- something this file should bet the restored trigger on. CREATE OR REPLACE is
-- correct under both answers, and it costs nothing when the answer was "it
-- survived".
--
-- WHY THE INDEX CARRIES NO `IF NOT EXISTS`. It does not need one: the statement
-- immediately above this block dropped the table the index belongs to, and
-- CASCADE dropped its indexes with it, so the name is free by construction at
-- the point this statement runs. `20260920232118956` declares the identical
-- index without the clause, and this file reproduces that declaration rather
-- than improving on it.
--


-- Partial unique index: exactly one 'approved' per work_item_id (enforced under concurrency)
CREATE UNIQUE INDEX "design_revision_approved_unique_per_work_item"
    ON "design_revision" USING btree ("workItemId")
    WHERE ("status" = 'approved');

-- DB-LEVEL ENFORCEMENT: Immutability trigger for design_revision
-- Reject content UPDATE where status = 'approved'
--
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

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261019010044759', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261019010044759', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
