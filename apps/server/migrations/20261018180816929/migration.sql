BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "design_contract" (
    "id" bigserial PRIMARY KEY,
    "contractId" text NOT NULL,
    "workItemId" text NOT NULL,
    "requiredArtifactsJson" text NOT NULL,
    "reviewersJson" text NOT NULL,
    "approvalThreshold" bigint NOT NULL,
    "status" text NOT NULL,
    "submittedArtifactsJson" text,
    "decisionsJson" text,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL,
    "expiresAt" timestamp without time zone,
    "metadataJson" text
);

-- Indexes
CREATE UNIQUE INDEX "design_contract_contract_id_unique" ON "design_contract" USING btree ("contractId");
CREATE INDEX "design_contract_work_item_idx" ON "design_contract" USING btree ("workItemId");


--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261018180816929', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261018180816929', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
