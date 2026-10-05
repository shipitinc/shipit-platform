BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "triage_result" (
    "id" bigserial PRIMARY KEY,
    "resultId" text NOT NULL,
    "defectId" text NOT NULL,
    "recommendedStatus" text NOT NULL,
    "recommendedClassification" text,
    "confidence" double precision NOT NULL,
    "suspectedCategory" text NOT NULL,
    "suspectedComponents" json NOT NULL,
    "reproductionSupported" boolean NOT NULL,
    "evidenceUsed" json NOT NULL,
    "clarificationRequired" text,
    "recommendedNextAction" text NOT NULL,
    "possibleDuplicateDefectId" text,
    "recommendedWorkItemCategory" text,
    "summary" text NOT NULL,
    "jobId" text NOT NULL,
    "executionId" text,
    "createdAt" timestamp without time zone NOT NULL,
    "completedAt" timestamp without time zone,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "result_id_unique" ON "triage_result" USING btree ("resultId");
CREATE INDEX "triage_result_defect_idx" ON "triage_result" USING btree ("defectId");
CREATE INDEX "triage_result_job_idx" ON "triage_result" USING btree ("jobId");
CREATE INDEX "triage_result_classification_idx" ON "triage_result" USING btree ("recommendedClassification");


--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260927041236430', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260927041236430', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
