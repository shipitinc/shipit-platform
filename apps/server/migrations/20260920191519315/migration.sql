BEGIN;

--
-- ACTION RENAME TABLE repository_credential -> product_credential
--
ALTER TABLE "repository_credential" RENAME TO "product_credential";

--
-- Rename indexes
--
ALTER INDEX "repository_credential_id_unique" RENAME TO "product_credential_id_unique";
ALTER INDEX "repository_credential_repo_idx" RENAME TO "product_credential_repo_idx";
ALTER INDEX "repository_credential_product_idx" RENAME TO "product_credential_product_idx";

--
-- ACTION CREATE TABLE baseline_fact
--
CREATE TABLE "baseline_fact" (
    "id" bigserial PRIMARY KEY,
    "factId" text NOT NULL,
    "baselineId" text NOT NULL,
    "section" text NOT NULL,
    "claim" text NOT NULL,
    "provenance" text NOT NULL,
    "maturity" text NOT NULL,
    "evidenceRefsJson" text,
    "assumptionNote" text,
    "redacted" boolean NOT NULL,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "baseline_fact_id_unique" ON "baseline_fact" USING btree ("factId");
CREATE INDEX "baseline_fact_baseline_idx" ON "baseline_fact" USING btree ("baselineId");

--
-- ACTION CREATE TABLE product_registry_audit
--
CREATE TABLE "product_registry_audit" (
    "id" bigserial PRIMARY KEY,
    "auditId" text NOT NULL,
    "productId" text NOT NULL,
    "entityType" text NOT NULL,
    "entityId" text NOT NULL,
    "action" text NOT NULL,
    "beforeJson" text,
    "afterJson" text,
    "actor" text,
    "timestamp" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "product_registry_audit_id_unique" ON "product_registry_audit" USING btree ("auditId");
CREATE INDEX "product_registry_audit_product_idx" ON "product_registry_audit" USING btree ("productId");
CREATE INDEX "product_registry_audit_timestamp_idx" ON "product_registry_audit" USING btree ("timestamp");


--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260920191519315', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260920191519315', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;