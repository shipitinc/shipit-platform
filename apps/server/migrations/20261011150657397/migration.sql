BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "operator_action" (
    "id" bigserial PRIMARY KEY,
    "actionId" text NOT NULL,
    "workItemId" text NOT NULL,
    "action" text NOT NULL,
    "fromState" text NOT NULL,
    "toState" text NOT NULL,
    "requestedBy" text NOT NULL,
    "reason" text NOT NULL,
    "requestId" text NOT NULL,
    "jobId" text,
    "transitionId" text,
    "attemptNumber" bigint,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "operator_action_id_unique" ON "operator_action" USING btree ("actionId");
CREATE INDEX "operator_action_work_item_idx" ON "operator_action" USING btree ("workItemId");
CREATE UNIQUE INDEX "operator_action_request_unique" ON "operator_action" USING btree ("workItemId", "requestId");
CREATE INDEX "operator_action_job_idx" ON "operator_action" USING btree ("jobId");
CREATE INDEX "operator_action_retry_idx" ON "operator_action" USING btree ("workItemId", "action");


--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261011150657397', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261011150657397', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
