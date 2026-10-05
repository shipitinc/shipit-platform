BEGIN;

--
-- SHIPIT CONTROL PLANE REPAIR
--
-- Both objects below are hand-maintained schema deviations that the Serverpod
-- model layer cannot express, so `serverpod create-migration` drops them from
-- every regenerated `definition.sql`. They are restored here additively. This
-- migration intentionally rewrites no earlier migration: `20260920232118956`
-- created `job_active_dedupe_unique` and `20260922004754773` silently dropped
-- it when the generator rebuilt the cumulative definition from the models.
-- Hiding that by editing history is not an option, so the loss is repaired
-- forward and recorded here.
--
--   1. `job_active_dedupe_unique` - partial unique index enforcing job dedupe
--      for active states (documented deviation - not expressible in Serverpod
--      models). Postgres treats NULLs as distinct, so deferred/duplicate-
--      enqueue NULL dedupe keys are not affected. Without it the `job` table
--      carried only the NON-unique `job_dedupe_key_idx`, so the database
--      enforced nothing: concurrent dedupe enqueues each inserted their own
--      row instead of one racer winning.
--   2. `design_review_result_execution_unique` - unique index backing the
--      `ON CONFLICT ("reviewExecutionId") DO UPDATE` upserts in the design
--      review store. `reviewExecutionId` is that upsert's idempotency key, so
--      the column is unique by contract; only the NON-unique
--      `design_review_result_execution_idx` existed, so every such upsert
--      failed with SQLSTATE 42P10 ("there is no unique or exclusion constraint
--      matching the ON CONFLICT specification").
--
-- Both statements are `IF NOT EXISTS`, so re-application is a no-op.
--
-- SAFETY / DATA LOSS: this migration deletes nothing and rewrites nothing. If
-- the target database already holds rows violating either uniqueness rule, the
-- CREATE below raises the violation, the surrounding transaction aborts, and
-- NO version row is written - the migration fails loudly and the operator
-- resolves the duplicates by hand. Resolving them automatically would mean
-- deleting job rows on a judgement call; that is a data-loss decision and is
-- deliberately not taken here.
--
CREATE UNIQUE INDEX IF NOT EXISTS "job_active_dedupe_unique"
    ON "job" USING btree ("dedupeKey")
    WHERE (("state" = 'queued') OR ("state" = 'claimed') OR ("state" = 'running') OR ("state" = 'retryWaiting'));

--
-- SHIPIT CONTROL PLANE: one design review result per review execution.
-- `reviewExecutionId` is the idempotency key of the review upsert, hence
-- unique. The model-declared `design_review_result_execution_idx` is left in
-- place: it is regenerated from `design_review_result.spy.yaml` on every
-- `serverpod create-migration` whereas this unique index is not, and a unique
-- btree index already serves every lookup the non-unique one served.
--
CREATE UNIQUE INDEX IF NOT EXISTS "design_review_result_execution_unique"
    ON "design_review_result" USING btree ("reviewExecutionId");

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260928233022000', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260928233022000', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
