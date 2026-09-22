BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "standing_policy" (
    "id" bigserial PRIMARY KEY,
    "policyId" text NOT NULL,
    "productId" text NOT NULL,
    "actionsJson" text NOT NULL,
    "authorisingDecisionId" text NOT NULL,
    "authorisedBy" text NOT NULL,
    "rationale" text NOT NULL,
    "authorisedAt" timestamp without time zone NOT NULL,
    "revokedAt" timestamp without time zone,
    "revokedBy" text,
    "revocationDecisionId" text,
    "revocationReason" text,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "standing_policy_id_unique" ON "standing_policy" USING btree ("policyId");
CREATE INDEX "standing_policy_product_idx" ON "standing_policy" USING btree ("productId");


--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260919232753476', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260919232753476', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
