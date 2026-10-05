BEGIN;

--
-- ACTION ALTER TABLE
--
-- Replaces the hand-written non-unique index on design_review_result with the
-- model-expressible unique constraint. Databases that applied an earlier
-- hand-written copy of the unique index still carry it under the same name, so
-- drop every predecessor before creating; the generator's diff source never
-- knew about that copy and cannot emit this drop itself.
DROP INDEX IF EXISTS "design_review_result_execution_idx";
DROP INDEX IF EXISTS "design_review_result_execution_unique";
CREATE UNIQUE INDEX "design_review_result_execution_unique" ON "design_review_result" USING btree ("reviewExecutionId");

--
-- ACTION ALTER TABLE
--
ALTER TABLE "job" ADD COLUMN "activeDedupeKey" text;

-- Backfill the derived active-dedupe column before the unique index is built.
-- The predicate mirrors PostgresJobStore's derivation exactly (non-null iff
-- the job is not terminal), so stored and backfilled rows can never disagree.
-- No duplicates are possible here: the partial index this replaces already
-- guaranteed that active dedupe keys were unique.
UPDATE "job"
   SET "activeDedupeKey" = "dedupeKey"
 WHERE "state" NOT IN ('succeeded', 'failed', 'cancelled');

-- The partial index this migration replaces carries the same name. The
-- generator's diff source cannot express a partial index, so it does not know
-- the old one exists and would otherwise collide on the CREATE below.
DROP INDEX IF EXISTS "job_active_dedupe_unique";
CREATE UNIQUE INDEX "job_active_dedupe_unique" ON "job" USING btree ("activeDedupeKey");

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260929123032034', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260929123032034', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
