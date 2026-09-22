BEGIN;

--
-- Class DefectRow as table defect
--
CREATE TABLE "defect" (
    "id" bigserial PRIMARY KEY,
    "defectId" text NOT NULL,
    "title" text NOT NULL,
    "description" text NOT NULL,
    "expectedBehavior" text,
    "reproductionSteps" text,
    "severity" text NOT NULL,
    "status" text NOT NULL,
    "classification" text,
    "reporter" text NOT NULL,
    "affectedWorkItemId" text,
    "affectedRunId" text,
    "remediationWorkItemId" text,
    "duplicateOfDefectId" text,
    "currentTriageJobId" text,
    "clientContextJson" text,
    "metadataJson" text,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL,
    "resolvedAt" timestamp without time zone,
    "closedAt" timestamp without time zone,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "defect_id_unique" ON "defect" USING btree ("defectId");
CREATE INDEX "defect_status_idx" ON "defect" USING btree ("status");
CREATE INDEX "defect_reporter_idx" ON "defect" USING btree ("reporter");
CREATE INDEX "defect_affected_work_item_idx" ON "defect" USING btree ("affectedWorkItemId");
CREATE INDEX "defect_classification_idx" ON "defect" USING btree ("classification");

--
-- Class DefectEvidenceRow as table defect_evidence
--
CREATE TABLE "defect_evidence" (
    "id" bigserial PRIMARY KEY,
    "evidenceId" text NOT NULL,
    "defectId" text NOT NULL,
    "kind" text NOT NULL,
    "artifactId" text,
    "contentHash" text,
    "description" text,
    "sourceRef" text,
    "capturedAt" timestamp without time zone NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "defect_evidence_id_unique" ON "defect_evidence" USING btree ("evidenceId");
CREATE INDEX "defect_evidence_defect_idx" ON "defect_evidence" USING btree ("defectId");
CREATE INDEX "defect_evidence_kind_idx" ON "defect_evidence" USING btree ("kind");

--
-- Class DefectEventRow as table defect_event
--
CREATE TABLE "defect_event" (
    "id" bigserial PRIMARY KEY,
    "eventId" text NOT NULL,
    "defectId" text NOT NULL,
    "sequence" bigint NOT NULL,
    "type" text NOT NULL,
    "fromStatus" text,
    "toStatus" text,
    "actorType" text NOT NULL,
    "actorId" text,
    "payloadJson" text,
    "occurredAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "defect_event_id_unique" ON "defect_event" USING btree ("eventId");
CREATE INDEX "defect_event_defect_idx" ON "defect_event" USING btree ("defectId");
CREATE UNIQUE INDEX "defect_event_defect_sequence_unique" ON "defect_event" USING btree ("defectId", "sequence");

--
-- Class DefectClarificationRow as table defect_clarification
--
CREATE TABLE "defect_clarification" (
    "id" bigserial PRIMARY KEY,
    "clarificationId" text NOT NULL,
    "defectId" text NOT NULL,
    "question" text NOT NULL,
    "reason" text NOT NULL,
    "status" text NOT NULL,
    "answer" text,
    "humanDecisionId" text,
    "requestedByTriageJobId" text,
    "requestedAt" timestamp without time zone NOT NULL,
    "answeredAt" timestamp without time zone,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "defect_clarification_id_unique" ON "defect_clarification" USING btree ("clarificationId");
CREATE INDEX "defect_clarification_defect_idx" ON "defect_clarification" USING btree ("defectId");
CREATE INDEX "defect_clarification_status_idx" ON "defect_clarification" USING btree ("status");

COMMIT;