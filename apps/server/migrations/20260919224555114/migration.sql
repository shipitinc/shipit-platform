BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "product_baseline" ADD COLUMN "verifiedAt" timestamp without time zone;
ALTER TABLE "product_baseline" ADD COLUMN "verifiedBy" text;
ALTER TABLE "product_baseline" ADD COLUMN "verificationKind" text;
--
-- ACTION CREATE TABLE
--
CREATE TABLE "repository_credential" (
    "id" bigserial PRIMARY KEY,
    "credentialId" text NOT NULL,
    "productId" text NOT NULL,
    "repositoryId" text NOT NULL,
    "referenceName" text NOT NULL,
    "publicKey" text NOT NULL,
    "fingerprint" text NOT NULL,
    "algorithm" text NOT NULL,
    "status" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "lastVerifiedAt" timestamp without time zone,
    "lastVerifiedBy" text,
    "lastFailureReason" text,
    "hostKeyStatus" text NOT NULL,
    "host" text,
    "hostKeyFingerprint" text,
    "hostConfirmedAt" timestamp without time zone,
    "hostConfirmedBy" text,
    "revokedAt" timestamp without time zone,
    "revokedReason" text,
    "supersedesCredentialId" text,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "repository_credential_id_unique" ON "repository_credential" USING btree ("credentialId");
CREATE INDEX "repository_credential_repo_idx" ON "repository_credential" USING btree ("repositoryId");
CREATE INDEX "repository_credential_product_idx" ON "repository_credential" USING btree ("productId");


--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260919224555114', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260919224555114', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
