BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "engineering_review_result" (
    "id" bigserial PRIMARY KEY,
    "reviewExecutionId" text NOT NULL,
    "revisionId" text NOT NULL,
    "verdict" text NOT NULL,
    "findingsJson" text NOT NULL,
    "assessedDimensionsJson" text NOT NULL,
    "reviewScopeJson" text,
    "createdAt" timestamp without time zone NOT NULL,
    "version" bigint NOT NULL
);

-- Indexes
CREATE INDEX "engineering_review_result_revision" ON "engineering_review_result" USING btree ("revisionId");
CREATE INDEX "engineering_review_result_verdict" ON "engineering_review_result" USING btree ("verdict");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "model_execution_record" (
    "id" bigserial PRIMARY KEY,
    "workItemId" text NOT NULL,
    "jobId" text NOT NULL,
    "agentExecutionId" text NOT NULL,
    "role" text NOT NULL,
    "modelId" text NOT NULL,
    "provider" text NOT NULL,
    "inputTokens" bigint NOT NULL,
    "outputTokens" bigint NOT NULL,
    "totalTokens" bigint NOT NULL,
    "cachedReadTokens" bigint NOT NULL,
    "costUsd" double precision NOT NULL,
    "currency" text NOT NULL,
    "startedAt" timestamp without time zone NOT NULL,
    "finishedAt" timestamp without time zone NOT NULL,
    "success" boolean NOT NULL,
    "error" text,
    "escalationIndex" bigint NOT NULL,
    "taskType" text NOT NULL
);

-- Indexes
CREATE INDEX "model_execution_record_work_item" ON "model_execution_record" USING btree ("workItemId");
CREATE INDEX "model_execution_record_job" ON "model_execution_record" USING btree ("jobId");
CREATE INDEX "model_execution_record_model_provider" ON "model_execution_record" USING btree ("modelId");
CREATE INDEX "model_execution_record_started_at" ON "model_execution_record" USING btree ("startedAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "model_policy" (
    "id" bigserial PRIMARY KEY,
    "role" text NOT NULL,
    "chainJson" text NOT NULL,
    "version" bigint NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL,
    "updatedByDecisionId" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "model_policy_role_unique" ON "model_policy" USING btree ("role");
CREATE INDEX "model_policy_version" ON "model_policy" USING btree ("version");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "qa_review_result" (
    "id" bigserial PRIMARY KEY,
    "reviewExecutionId" text NOT NULL,
    "revisionId" text NOT NULL,
    "verdict" text NOT NULL,
    "findingsJson" text NOT NULL,
    "assessedDimensionsJson" text NOT NULL,
    "reviewScopeJson" text,
    "createdAt" timestamp without time zone NOT NULL,
    "version" bigint NOT NULL
);

-- Indexes
CREATE INDEX "qa_review_result_revision" ON "qa_review_result" USING btree ("revisionId");
CREATE INDEX "qa_review_result_verdict" ON "qa_review_result" USING btree ("verdict");

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261001205247600', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261001205247600', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


--
-- DOWN MIGRATION
--
-- To rollback this migration, run the following:
--
-- BEGIN;
--
-- -- Drop tables in reverse order
-- DROP TABLE IF EXISTS "qa_review_result";
-- DROP TABLE IF EXISTS "model_policy";
-- DROP TABLE IF EXISTS "model_execution_record";
-- DROP TABLE IF EXISTS "engineering_review_result";
--
-- -- Migration version rollback for control_plane
-- DELETE FROM "serverpod_migrations" WHERE "module" = 'control_plane' AND "version" = '20261001205247600';
--
-- COMMIT;


COMMIT;
