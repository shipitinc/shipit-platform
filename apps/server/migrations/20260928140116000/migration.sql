BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "qa_contract" (
    "contract_id" text NOT NULL,
    "work_item_category" text NOT NULL,
    "gates" jsonb NOT NULL,
    "version" text NOT NULL,
    "pass_criteria" jsonb,
    "created_at" timestamp without time zone NOT NULL,
    "updated_at" timestamp without time zone NOT NULL,
    "evidence_rows" jsonb,
    "metadata" jsonb,
    CONSTRAINT "qa_contract_contract_id_pk" PRIMARY KEY ("contract_id")
);

-- Indexes
CREATE INDEX "qa_contract_work_item_category_idx" ON "qa_contract" USING btree ("work_item_category");

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260928140116000', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260928140116000', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
