BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "human_direction" (
    "id" bigserial PRIMARY KEY,
    "directionId" text NOT NULL,
    "directionType" text NOT NULL,
    "targetType" text NOT NULL,
    "targetId" text,
    "status" text NOT NULL,
    "payloadJson" text NOT NULL,
    "createdBy" text,
    "assignedTo" text,
    "ackedAt" timestamp without time zone,
    "ackedBy" text,
    "startedAt" timestamp without time zone,
    "startedBy" text,
    "completedAt" timestamp without time zone,
    "completedBy" text,
    "completionSummary" text,
    "rejectedAt" timestamp without time zone,
    "rejectedBy" text,
    "rejectionReason" text,
    "supersededAt" timestamp without time zone,
    "supersededByDirectionId" text,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL,
    "metadataJson" text
);

-- Indexes
CREATE UNIQUE INDEX "human_direction_id_unique" ON "human_direction" USING btree ("directionId");
CREATE INDEX "human_direction_target_idx" ON "human_direction" USING btree ("targetType", "targetId");
CREATE INDEX "human_direction_status_idx" ON "human_direction" USING btree ("status");
CREATE INDEX "human_direction_created_by_idx" ON "human_direction" USING btree ("createdBy");


--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260925052148069', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260925052148069', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
