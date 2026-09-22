BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "clarification_request" (
    "id" bigserial PRIMARY KEY,
    "clarificationId" text NOT NULL,
    "productId" text NOT NULL,
    "onboardingId" text NOT NULL,
    "section" text NOT NULL,
    "question" text NOT NULL,
    "status" text NOT NULL,
    "answer" text,
    "createdAt" timestamp without time zone NOT NULL,
    "answeredAt" timestamp without time zone,
    "answeredBy" text
);

-- Indexes
CREATE UNIQUE INDEX "clarification_request_id_unique" ON "clarification_request" USING btree ("clarificationId");
CREATE INDEX "clarification_request_product_idx" ON "clarification_request" USING btree ("productId");
CREATE INDEX "clarification_request_status_idx" ON "clarification_request" USING btree ("status");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "onboarding_record" (
    "id" bigserial PRIMARY KEY,
    "onboardingId" text NOT NULL,
    "productId" text NOT NULL,
    "currentBaselineRevision" bigint NOT NULL,
    "pendingClarifications" bigint NOT NULL,
    "completed" boolean NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "onboarding_product_unique" ON "onboarding_record" USING btree ("productId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "product" (
    "id" bigserial PRIMARY KEY,
    "productId" text NOT NULL,
    "name" text NOT NULL,
    "description" text,
    "manifestVersion" text,
    "state" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "product_id_unique" ON "product" USING btree ("productId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "product_baseline" (
    "id" bigserial PRIMARY KEY,
    "baselineId" text NOT NULL,
    "productId" text NOT NULL,
    "revision" bigint NOT NULL,
    "status" text NOT NULL,
    "factsJson" text NOT NULL,
    "contentHash" text NOT NULL,
    "contentHashVersion" bigint NOT NULL,
    "supersedesBaselineId" text,
    "proposedAt" timestamp without time zone,
    "reviewedAt" timestamp without time zone,
    "acceptedAt" timestamp without time zone,
    "acceptedBy" text,
    "acceptedDecisionId" text,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "product_baseline_id_unique" ON "product_baseline" USING btree ("baselineId");
CREATE UNIQUE INDEX "product_baseline_product_revision_unique" ON "product_baseline" USING btree ("productId", "revision");
CREATE INDEX "product_baseline_product_idx" ON "product_baseline" USING btree ("productId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "repository_reference" (
    "id" bigserial PRIMARY KEY,
    "repositoryId" text NOT NULL,
    "productId" text NOT NULL,
    "kind" text NOT NULL,
    "uri" text NOT NULL,
    "provider" text NOT NULL,
    "addedAt" timestamp without time zone NOT NULL,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "repository_reference_id_unique" ON "repository_reference" USING btree ("repositoryId");
CREATE INDEX "repository_reference_product_idx" ON "repository_reference" USING btree ("productId");


--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260918042016467', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260918042016467', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
