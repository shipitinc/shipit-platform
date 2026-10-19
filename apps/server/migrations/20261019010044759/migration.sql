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
