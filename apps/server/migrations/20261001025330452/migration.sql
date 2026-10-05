BEGIN;

-- Convert the hand-written `qa_contract` table (created by
-- 20260928140116000) into the managed table declared by
-- lib/src/database/qa_contract.spy.yaml, preserving every stored contract.
--
-- The generator emitted `CREATE TABLE IF NOT EXISTS`, which is a no-op against
-- the table that already exists: its columns are snake_case, the four JSON
-- columns are `jsonb`, there is no `id`, and the primary key is
-- `qa_contract_contract_id_pk` on `contract_id`. Serverpod's model declares
-- camelCase columns, `text` JSON payloads, an `id` primary key and a unique
-- index on `contractId`, so the shape has to be altered in place.
--
-- Ordering matters: the old primary key constraint must be dropped before
-- `id` can become the primary key, and `contract_id` must be indexed before it
-- is dropped as a constraint. `gatesJson` is NOT NULL, so it is backfilled
-- before the NOT NULL is enforced on the renamed column.

-- JSON payloads: `jsonb` -> `text`, keeping the document verbatim.
ALTER TABLE "qa_contract" ALTER COLUMN "gates" TYPE text USING "gates"::text;
ALTER TABLE "qa_contract" ALTER COLUMN "pass_criteria" TYPE text USING "pass_criteria"::text;
ALTER TABLE "qa_contract" ALTER COLUMN "evidence_rows" TYPE text USING "evidence_rows"::text;
ALTER TABLE "qa_contract" ALTER COLUMN "metadata" TYPE text USING "metadata"::text;

-- identity column, backfilled for existing rows.
ALTER TABLE "qa_contract" ADD COLUMN "id" bigserial;
UPDATE "qa_contract" SET "id" = nextval(pg_get_serial_sequence('qa_contract', 'id'))
 WHERE "id" IS NULL;
ALTER TABLE "qa_contract" ALTER COLUMN "id" SET NOT NULL;

-- The generator's diff source does not know the old primary key exists, so it
-- cannot emit this drop itself.
ALTER TABLE "qa_contract" DROP CONSTRAINT IF EXISTS "qa_contract_contract_id_pk";
ALTER TABLE "qa_contract" ADD PRIMARY KEY ("id");

-- snake_case -> camelCase.
ALTER TABLE "qa_contract" RENAME COLUMN "contract_id" TO "contractId";
ALTER TABLE "qa_contract" RENAME COLUMN "work_item_category" TO "workItemCategory";
ALTER TABLE "qa_contract" RENAME COLUMN "gates" TO "gatesJson";
ALTER TABLE "qa_contract" RENAME COLUMN "pass_criteria" TO "passCriteriaJson";
ALTER TABLE "qa_contract" RENAME COLUMN "created_at" TO "createdAt";
ALTER TABLE "qa_contract" RENAME COLUMN "updated_at" TO "updatedAt";
ALTER TABLE "qa_contract" RENAME COLUMN "evidence_rows" TO "evidenceRowsJson";
ALTER TABLE "qa_contract" RENAME COLUMN "metadata" TO "metadataJson";

-- Indexes: the generator emits these as IF NOT EXISTS, so dropping the
-- predecessors first is safe and lets a re-run converge.
DROP INDEX IF EXISTS "qa_contract_work_item_category_idx";
CREATE INDEX "qa_contract_work_item_category_idx" ON "qa_contract" USING btree ("workItemCategory");
CREATE UNIQUE INDEX "qa_contract_id_unique" ON "qa_contract" USING btree ("contractId");

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261001025330452', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261001025330452', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
