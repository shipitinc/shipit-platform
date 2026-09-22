BEGIN;

--
-- Class AgentEventRow as table agent_event
--
CREATE TABLE "agent_event" (
    "id" bigserial PRIMARY KEY,
    "eventId" text NOT NULL,
    "executionId" text NOT NULL,
    "workItemId" text NOT NULL,
    "sequence" bigint NOT NULL,
    "type" text NOT NULL,
    "occurredAt" timestamp without time zone NOT NULL,
    "payloadJson" text
);

-- Indexes
CREATE UNIQUE INDEX "agent_event_id_unique" ON "agent_event" USING btree ("eventId");
CREATE INDEX "agent_event_execution_idx" ON "agent_event" USING btree ("executionId");
CREATE UNIQUE INDEX "agent_event_execution_sequence_unique" ON "agent_event" USING btree ("executionId", "sequence");

--
-- Class AgentExecutionRow as table agent_execution
--
CREATE TABLE "agent_execution" (
    "id" bigserial PRIMARY KEY,
    "executionId" text NOT NULL,
    "workItemId" text NOT NULL,
    "requestId" text NOT NULL,
    "runtimeTypeId" text NOT NULL,
    "role" text NOT NULL,
    "status" text NOT NULL,
    "workspaceJson" text NOT NULL,
    "sessionId" text,
    "resultId" text,
    "startedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    "reason" text,
    "metadataJson" text,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "agent_execution_id_unique" ON "agent_execution" USING btree ("executionId");
CREATE INDEX "agent_execution_work_item_idx" ON "agent_execution" USING btree ("workItemId");

--
-- Class AgentExecutionRequestRow as table agent_execution_request
--
CREATE TABLE "agent_execution_request" (
    "id" bigserial PRIMARY KEY,
    "executionId" text NOT NULL,
    "workItemId" text NOT NULL,
    "role" text NOT NULL,
    "runtimeTypeId" text NOT NULL,
    "workspaceJson" text NOT NULL,
    "instruction" text NOT NULL,
    "timeoutSeconds" bigint NOT NULL,
    "permittedScope" text,
    "expectedResultJson" text,
    "expectedArtifactsJson" text NOT NULL,
    "runtimeConfigJson" text,
    "environmentJson" text,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "agent_execution_request_id_unique" ON "agent_execution_request" USING btree ("executionId");

--
-- Class AgentResultRow as table agent_result
--
CREATE TABLE "agent_result" (
    "id" bigserial PRIMARY KEY,
    "resultId" text NOT NULL,
    "sessionId" text NOT NULL,
    "workItemId" text NOT NULL,
    "status" text NOT NULL,
    "artifactsJson" text NOT NULL,
    "diagnosticsJson" text NOT NULL,
    "structuredResultJson" text NOT NULL,
    "executionId" text,
    "role" text,
    "changedFilesJson" text,
    "claimedChecksJson" text,
    "summary" text,
    "completedAt" timestamp without time zone NOT NULL,
    "metadataJson" text
);

-- Indexes
CREATE UNIQUE INDEX "agent_result_execution_unique" ON "agent_result" USING btree ("executionId");

--
-- Class HumanDecisionRow as table human_decision
--
CREATE TABLE "human_decision" (
    "id" bigserial PRIMARY KEY,
    "decisionId" text NOT NULL,
    "workItemId" text NOT NULL,
    "decisionType" text NOT NULL,
    "status" text NOT NULL,
    "question" text,
    "contextJson" text,
    "optionsJson" text,
    "recommendation" text,
    "blocking" boolean,
    "requestedAt" timestamp without time zone,
    "expiration" timestamp without time zone,
    "decider" text,
    "choice" text,
    "rationale" text,
    "timestamp" timestamp without time zone,
    "signatureJson" text,
    "resolvedOptionId" text,
    "metadataJson" text,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "human_decision_id_unique" ON "human_decision" USING btree ("decisionId");
CREATE INDEX "human_decision_work_item_idx" ON "human_decision" USING btree ("workItemId");

--
-- Class JobRow as table job
--
CREATE TABLE "job" (
    "id" bigserial PRIMARY KEY,
    "jobId" text NOT NULL,
    "workItemId" text NOT NULL,
    "jobType" text NOT NULL,
    "requiredRole" text NOT NULL,
    "requiredCapabilitiesJson" text NOT NULL,
    "priority" text NOT NULL,
    "state" text NOT NULL,
    "dedupeKey" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "availableAt" timestamp without time zone,
    "instruction" text NOT NULL,
    "attempt" bigint NOT NULL,
    "maxAttempts" bigint NOT NULL,
    "startedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    "executionReferenceJson" text,
    "workerId" text,
    "failureJson" text,
    "cancelReason" text,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "job_id_unique" ON "job" USING btree ("jobId");
CREATE INDEX "job_work_item_idx" ON "job" USING btree ("workItemId");
CREATE INDEX "job_dedupe_key_idx" ON "job" USING btree ("dedupeKey");

--
-- Class JobClaimRow as table job_claim
--
CREATE TABLE "job_claim" (
    "id" bigserial PRIMARY KEY,
    "claimId" text NOT NULL,
    "jobId" text NOT NULL,
    "ownerId" text NOT NULL,
    "leasedUntil" timestamp without time zone NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "job_claim_id_unique" ON "job_claim" USING btree ("claimId");
CREATE UNIQUE INDEX "job_claim_job_unique" ON "job_claim" USING btree ("jobId");

--
-- Class PlatformVerificationRow as table platform_verification
--
CREATE TABLE "platform_verification" (
    "id" bigserial PRIMARY KEY,
    "verificationId" text NOT NULL,
    "executionId" text NOT NULL,
    "workItemId" text NOT NULL,
    "checkName" text NOT NULL,
    "status" text NOT NULL,
    "mechanism" text NOT NULL,
    "command" text NOT NULL,
    "capturedAt" timestamp without time zone NOT NULL,
    "evidenceKind" text NOT NULL,
    "outputRef" text,
    "detail" text,
    "resultPath" text
);

-- Indexes
CREATE UNIQUE INDEX "platform_verification_id_unique" ON "platform_verification" USING btree ("verificationId");
CREATE INDEX "platform_verification_execution_idx" ON "platform_verification" USING btree ("executionId");

--
-- Class SchedulerEventRow as table scheduler_event
--
CREATE TABLE "scheduler_event" (
    "id" bigserial PRIMARY KEY,
    "eventId" text NOT NULL,
    "jobId" text NOT NULL,
    "workItemId" text NOT NULL,
    "sequence" bigint NOT NULL,
    "type" text NOT NULL,
    "occurredAt" timestamp without time zone NOT NULL,
    "payloadJson" text
);

-- Indexes
CREATE UNIQUE INDEX "scheduler_event_id_unique" ON "scheduler_event" USING btree ("eventId");
CREATE INDEX "scheduler_event_job_idx" ON "scheduler_event" USING btree ("jobId");
CREATE UNIQUE INDEX "scheduler_event_job_sequence_unique" ON "scheduler_event" USING btree ("jobId", "sequence");

--
-- Class WorkItemRow as table work_item
--
CREATE TABLE "work_item" (
    "id" bigserial PRIMARY KEY,
    "workItemId" text NOT NULL,
    "productId" text NOT NULL,
    "category" text NOT NULL,
    "title" text NOT NULL,
    "description" text,
    "state" text NOT NULL,
    "designContractId" text,
    "agentSessionId" text,
    "qaContractId" text,
    "featureRef" text,
    "requirementRef" text,
    "blockingHumanDecisionId" text,
    "blockingReason" text,
    "artifactRefsJson" text,
    "metadataJson" text,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL,
    "completedAt" timestamp without time zone,
    "terminatedAt" timestamp without time zone,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "work_item_work_item_id_unique" ON "work_item" USING btree ("workItemId");
CREATE INDEX "work_item_state_idx" ON "work_item" USING btree ("state");

--
-- Class WorkItemTransitionRow as table work_item_transition
--
CREATE TABLE "work_item_transition" (
    "id" bigserial PRIMARY KEY,
    "transitionId" text NOT NULL,
    "workItemId" text NOT NULL,
    "fromState" text NOT NULL,
    "toState" text NOT NULL,
    "trigger" text NOT NULL,
    "actorType" text NOT NULL,
    "actorId" text,
    "decisionId" text,
    "outcome" text NOT NULL,
    "reason" text,
    "guardEvaluationsJson" text,
    "idempotencyKey" text,
    "occurredAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "work_item_transition_id_unique" ON "work_item_transition" USING btree ("transitionId");
CREATE INDEX "work_item_transition_work_item_idx" ON "work_item_transition" USING btree ("workItemId");
CREATE UNIQUE INDEX "work_item_transition_idempotency_unique" ON "work_item_transition" USING btree ("workItemId", "idempotencyKey");

--
-- Class WorkerEventRow as table worker_event
--
CREATE TABLE "worker_event" (
    "id" bigserial PRIMARY KEY,
    "eventId" text NOT NULL,
    "workerExecutionId" text NOT NULL,
    "workItemId" text NOT NULL,
    "sequence" bigint NOT NULL,
    "type" text NOT NULL,
    "occurredAt" timestamp without time zone NOT NULL,
    "payloadJson" text
);

-- Indexes
CREATE UNIQUE INDEX "worker_event_id_unique" ON "worker_event" USING btree ("eventId");
CREATE INDEX "worker_event_execution_idx" ON "worker_event" USING btree ("workerExecutionId");
CREATE UNIQUE INDEX "worker_event_execution_sequence_unique" ON "worker_event" USING btree ("workerExecutionId", "sequence");

--
-- Class WorkerExecutionRow as table worker_execution
--
CREATE TABLE "worker_execution" (
    "id" bigserial PRIMARY KEY,
    "workerExecutionId" text NOT NULL,
    "workItemId" text NOT NULL,
    "repositoryPath" text NOT NULL,
    "requestedStartingRevision" text NOT NULL,
    "requiredCapabilitiesJson" text,
    "status" text NOT NULL,
    "cleanupPolicy" text NOT NULL,
    "workerId" text,
    "workspaceId" text,
    "agentExecutionId" text,
    "resultId" text,
    "endingRevision" text,
    "cleanupStatus" text,
    "failureCode" text,
    "createdAt" timestamp without time zone,
    "startedAt" timestamp without time zone,
    "endedAt" timestamp without time zone,
    "reason" text,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "worker_execution_id_unique" ON "worker_execution" USING btree ("workerExecutionId");
CREATE INDEX "worker_execution_work_item_idx" ON "worker_execution" USING btree ("workItemId");

--
-- Class WorkerRegistrationRow as table worker_registration
--
CREATE TABLE "worker_registration" (
    "id" bigserial PRIMARY KEY,
    "workerId" text NOT NULL,
    "poolId" text NOT NULL,
    "capabilitiesJson" text NOT NULL,
    "status" text NOT NULL,
    "currentLoad" bigint NOT NULL,
    "maxConcurrency" bigint NOT NULL,
    "lastHeartbeat" timestamp without time zone NOT NULL,
    "artifactCacheJson" text,
    "platform" text
);

-- Indexes
CREATE UNIQUE INDEX "worker_registration_id_unique" ON "worker_registration" USING btree ("workerId");

--
-- Class WorkerResultRow as table worker_result
--
CREATE TABLE "worker_result" (
    "id" bigserial PRIMARY KEY,
    "workerExecutionId" text NOT NULL,
    "workItemId" text NOT NULL,
    "status" text NOT NULL,
    "workerId" text NOT NULL,
    "workspaceId" text NOT NULL,
    "startingRevision" text NOT NULL,
    "endingRevision" text,
    "agentExecutionId" text,
    "agentResultStatus" text,
    "verificationId" text,
    "verificationPassed" boolean,
    "changedFilesJson" text,
    "diffSummary" text,
    "diffRef" text,
    "cleanupStatus" text NOT NULL,
    "failureCode" text NOT NULL,
    "failureDetail" text,
    "startedAt" timestamp without time zone NOT NULL,
    "endedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "worker_result_execution_unique" ON "worker_result" USING btree ("workerExecutionId");
CREATE INDEX "worker_result_work_item_idx" ON "worker_result" USING btree ("workItemId");

--
-- Class CloudStorageEntry as table serverpod_cloud_storage
--
CREATE TABLE "serverpod_cloud_storage" (
    "id" bigserial PRIMARY KEY,
    "storageId" text NOT NULL,
    "path" text NOT NULL,
    "addedTime" timestamp without time zone NOT NULL,
    "expiration" timestamp without time zone,
    "byteData" bytea NOT NULL,
    "verified" boolean NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_cloud_storage_path_idx" ON "serverpod_cloud_storage" USING btree ("storageId", "path");
CREATE INDEX "serverpod_cloud_storage_expiration" ON "serverpod_cloud_storage" USING btree ("expiration");

--
-- Class CloudStorageDirectUploadEntry as table serverpod_cloud_storage_direct_upload
--
CREATE TABLE "serverpod_cloud_storage_direct_upload" (
    "id" bigserial PRIMARY KEY,
    "storageId" text NOT NULL,
    "path" text NOT NULL,
    "expiration" timestamp without time zone NOT NULL,
    "authKey" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_cloud_storage_direct_upload_storage_path" ON "serverpod_cloud_storage_direct_upload" USING btree ("storageId", "path");

--
-- Class FutureCallEntry as table serverpod_future_call
--
CREATE TABLE "serverpod_future_call" (
    "id" bigserial PRIMARY KEY,
    "name" text NOT NULL,
    "time" timestamp without time zone NOT NULL,
    "serializedObject" text,
    "serverId" text NOT NULL,
    "identifier" text
);

-- Indexes
CREATE INDEX "serverpod_future_call_time_idx" ON "serverpod_future_call" USING btree ("time");
CREATE INDEX "serverpod_future_call_serverId_idx" ON "serverpod_future_call" USING btree ("serverId");
CREATE INDEX "serverpod_future_call_identifier_idx" ON "serverpod_future_call" USING btree ("identifier");

--
-- Class ServerHealthConnectionInfo as table serverpod_health_connection_info
--
CREATE TABLE "serverpod_health_connection_info" (
    "id" bigserial PRIMARY KEY,
    "serverId" text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    "active" bigint NOT NULL,
    "closing" bigint NOT NULL,
    "idle" bigint NOT NULL,
    "granularity" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_health_connection_info_timestamp_idx" ON "serverpod_health_connection_info" USING btree ("timestamp", "serverId", "granularity");

--
-- Class ServerHealthMetric as table serverpod_health_metric
--
CREATE TABLE "serverpod_health_metric" (
    "id" bigserial PRIMARY KEY,
    "name" text NOT NULL,
    "serverId" text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    "isHealthy" boolean NOT NULL,
    "value" double precision NOT NULL,
    "granularity" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_health_metric_timestamp_idx" ON "serverpod_health_metric" USING btree ("timestamp", "serverId", "name", "granularity");

--
-- Class LogEntry as table serverpod_log
--
CREATE TABLE "serverpod_log" (
    "id" bigserial PRIMARY KEY,
    "sessionLogId" bigint NOT NULL,
    "messageId" bigint,
    "reference" text,
    "serverId" text NOT NULL,
    "time" timestamp without time zone NOT NULL,
    "logLevel" bigint NOT NULL,
    "message" text NOT NULL,
    "error" text,
    "stackTrace" text,
    "order" bigint NOT NULL
);

-- Indexes
CREATE INDEX "serverpod_log_sessionLogId_idx" ON "serverpod_log" USING btree ("sessionLogId");

--
-- Class MessageLogEntry as table serverpod_message_log
--
CREATE TABLE "serverpod_message_log" (
    "id" bigserial PRIMARY KEY,
    "sessionLogId" bigint NOT NULL,
    "serverId" text NOT NULL,
    "messageId" bigint NOT NULL,
    "endpoint" text NOT NULL,
    "messageName" text NOT NULL,
    "duration" double precision NOT NULL,
    "error" text,
    "stackTrace" text,
    "slow" boolean NOT NULL,
    "order" bigint NOT NULL
);

--
-- Class MethodInfo as table serverpod_method
--
CREATE TABLE "serverpod_method" (
    "id" bigserial PRIMARY KEY,
    "endpoint" text NOT NULL,
    "method" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_method_endpoint_method_idx" ON "serverpod_method" USING btree ("endpoint", "method");

--
-- Class DatabaseMigrationVersion as table serverpod_migrations
--
CREATE TABLE "serverpod_migrations" (
    "id" bigserial PRIMARY KEY,
    "module" text NOT NULL,
    "version" text NOT NULL,
    "timestamp" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_migrations_ids" ON "serverpod_migrations" USING btree ("module");

--
-- Class QueryLogEntry as table serverpod_query_log
--
CREATE TABLE "serverpod_query_log" (
    "id" bigserial PRIMARY KEY,
    "serverId" text NOT NULL,
    "sessionLogId" bigint NOT NULL,
    "messageId" bigint,
    "query" text NOT NULL,
    "duration" double precision NOT NULL,
    "numRows" bigint,
    "error" text,
    "stackTrace" text,
    "slow" boolean NOT NULL,
    "order" bigint NOT NULL
);

-- Indexes
CREATE INDEX "serverpod_query_log_sessionLogId_idx" ON "serverpod_query_log" USING btree ("sessionLogId");

--
-- Class ReadWriteTestEntry as table serverpod_readwrite_test
--
CREATE TABLE "serverpod_readwrite_test" (
    "id" bigserial PRIMARY KEY,
    "number" bigint NOT NULL
);

--
-- Class RuntimeSettings as table serverpod_runtime_settings
--
CREATE TABLE "serverpod_runtime_settings" (
    "id" bigserial PRIMARY KEY,
    "logSettings" json NOT NULL,
    "logSettingsOverrides" json NOT NULL,
    "logServiceCalls" boolean NOT NULL,
    "logMalformedCalls" boolean NOT NULL
);

--
-- Class SessionLogEntry as table serverpod_session_log
--
CREATE TABLE "serverpod_session_log" (
    "id" bigserial PRIMARY KEY,
    "serverId" text NOT NULL,
    "time" timestamp without time zone NOT NULL,
    "module" text,
    "endpoint" text,
    "method" text,
    "duration" double precision,
    "numQueries" bigint,
    "slow" boolean,
    "error" text,
    "stackTrace" text,
    "authenticatedUserId" bigint,
    "userId" text,
    "isOpen" boolean,
    "touched" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "serverpod_session_log_serverid_idx" ON "serverpod_session_log" USING btree ("serverId");
CREATE INDEX "serverpod_session_log_time_idx" ON "serverpod_session_log" USING btree ("time");
CREATE INDEX "serverpod_session_log_touched_idx" ON "serverpod_session_log" USING btree ("touched");
CREATE INDEX "serverpod_session_log_isopen_idx" ON "serverpod_session_log" USING btree ("isOpen");

--
-- Foreign relations for "serverpod_log" table
--
ALTER TABLE ONLY "serverpod_log"
    ADD CONSTRAINT "serverpod_log_fk_0"
    FOREIGN KEY("sessionLogId")
    REFERENCES "serverpod_session_log"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- Foreign relations for "serverpod_message_log" table
--
ALTER TABLE ONLY "serverpod_message_log"
    ADD CONSTRAINT "serverpod_message_log_fk_0"
    FOREIGN KEY("sessionLogId")
    REFERENCES "serverpod_session_log"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- Foreign relations for "serverpod_query_log" table
--
ALTER TABLE ONLY "serverpod_query_log"
    ADD CONSTRAINT "serverpod_query_log_fk_0"
    FOREIGN KEY("sessionLogId")
    REFERENCES "serverpod_session_log"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260914041810984', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260914041810984', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


--
-- SHIPIT CONTROL PLANE: partial unique index enforcing job dedupe for active
-- states (documented deviation - not expressible in Serverpod models).
-- Postgres treats NULLs as distinct, so deferred/duplicate-enqueue NULL dedupe
-- keys are not affected.
--
CREATE UNIQUE INDEX "job_active_dedupe_unique"
    ON "job" USING btree ("dedupeKey")
    WHERE (("state" = 'queued') OR ("state" = 'claimed') OR ("state" = 'running') OR ("state" = 'retryWaiting'));

COMMIT;
