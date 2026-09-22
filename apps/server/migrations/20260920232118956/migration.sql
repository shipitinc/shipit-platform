BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "design_finding" (
    "id" bigserial PRIMARY KEY,
    "findingId" text NOT NULL,
    "revisionId" text NOT NULL,
    "reviewExecutionId" text NOT NULL,
    "category" text NOT NULL,
    "severity" text NOT NULL,
    "dimension" text NOT NULL,
    "evidence" text NOT NULL,
    "requiredCorrection" text NOT NULL,
    "affectedSurface" text NOT NULL,
    "resolvedByRevisionId" text,
    "createdAt" timestamp without time zone NOT NULL,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "design_finding_id_unique" ON "design_finding" USING btree ("findingId");
CREATE INDEX "design_finding_revision_idx" ON "design_finding" USING btree ("revisionId");
CREATE INDEX "design_finding_review_execution_idx" ON "design_finding" USING btree ("reviewExecutionId");
CREATE INDEX "design_finding_resolved_by_idx" ON "design_finding" USING btree ("resolvedByRevisionId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "design_review_result" (
    "id" bigserial PRIMARY KEY,
    "reviewResultId" text NOT NULL,
    "revisionId" text NOT NULL,
    "reviewExecutionId" text NOT NULL,
    "verdict" text NOT NULL,
    "findingsJson" text NOT NULL,
    "assessedDimensionsJson" text NOT NULL,
    "reviewScopeJson" text,
    "createdAt" timestamp without time zone NOT NULL,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "design_review_result_id_unique" ON "design_review_result" USING btree ("reviewResultId");
CREATE INDEX "design_review_result_revision_idx" ON "design_review_result" USING btree ("revisionId");
CREATE INDEX "design_review_result_execution_idx" ON "design_review_result" USING btree ("reviewExecutionId");

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

-- Partial unique index: exactly one 'approved' per work_item_id (enforced under concurrency)
CREATE UNIQUE INDEX "design_revision_approved_unique_per_work_item"
    ON "design_revision" USING btree ("workItemId")
    WHERE ("status" = 'approved');

--
-- ACTION CREATE TABLE
--
CREATE TABLE "design_revision_event" (
    "id" bigserial PRIMARY KEY,
    "eventId" text NOT NULL,
    "designRevisionId" text NOT NULL,
    "eventType" text NOT NULL,
    "payloadJson" text NOT NULL,
    "sequence" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "design_revision_event_id_unique" ON "design_revision_event" USING btree ("eventId");
CREATE INDEX "design_revision_event_revision_idx" ON "design_revision_event" USING btree ("designRevisionId");
CREATE UNIQUE INDEX "design_revision_event_sequence_idx" ON "design_revision_event" USING btree ("designRevisionId", "sequence");

--
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
-- DB-LEVEL ENFORCEMENT: Independence trigger for design_review_result
-- Reject insert where review_execution_id == revision's designer_execution_id
--
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

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260920232118956', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260920232118956', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


--
-- SHIPIT CONTROL PLANE: partial unique index enforcing job dedupe for active
-- states (documented deviation - not expressible in Serverpod models).
-- Postgres treats NULLs as distinct, so deferred/duplicate-enqueue NULL dedupe
-- keys are not affected.
--
CREATE UNIQUE INDEX "job_active_dedupe_unique"
    ON "job" USING btree ("dedupeKey")
    WHERE (("state" = 'queued') OR ("state" = 'claimed') OR ("state" = 'running') OR ("state" = 'retryWaiting'));

COMMIT;