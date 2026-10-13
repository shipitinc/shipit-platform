BEGIN;

--
-- ACTION ALTER TABLE
--
-- ONBOARDING RECORD: the durable home of a Product's pinned git revision and
-- its workspace.
--
-- WHY THIS MIGRATION EXISTS. Nothing in the schema could answer "which commit
-- is this product at?" or "where does its code live on disk?".
-- `onboarding_record.currentBaselineRevision` is a bigint SEQUENCE COUNTER
-- (`nextBaselineRevision` = max + 1), not a content address, so no clone could
-- ever be located from it. The only revision columns in the schema were
-- per-EXECUTION (`worker_execution.startingRevision`/`endingRevision`,
-- `agent_execution.workspaceJson`), which answer a different question: what
-- did THIS execution start from, not what is the product pinned to.
-- `WorkspaceDescriptor` existed as a type and was returned by
-- `ControlPlaneService.getOnboardingStatus` — where it was declared and never
-- assigned, so the field was structurally always null — but it was persisted
-- NOWHERE.
--
-- WHY ONE TABLE AND NOT A NEW `workspace` TABLE. `onboarding_record` is
-- already one row per product, already unique on `productId`
-- (`onboarding_product_unique`), and already the thing `saveOnboarding` /
-- `readOnboardingForProduct` round-trip. A separate table would be a SECOND
-- home for the same answer and would have to be joined, CAS'd and torn down in
-- step with this one to stay consistent. The descriptor stays a JSON document
-- for the same reason `baseline_fact` is one: it is a value object that is
-- always read and written whole.
--
-- WHY ALL THREE COLUMNS ARE NULLABLE. A Product is registered long before
-- anyone clones it, so "not pinned yet" is an ordinary state, not a defect.
-- NOT NULL here would force the engine to fabricate a commit it does not have
-- — and `currentBaselineRevision = 0` is exactly that fabrication, already in
-- the type for the counter. A row written before this migration is therefore
-- readable after it without a backfill, which is what makes this migration
-- purely additive.
--
--   "pinnedRevision"      full lowercase 40-hex commit SHA. TEXT, not an int:
--                         an int cannot hold a SHA, and ADR 0012's own artifact
--                         model keeps `ArtifactManifest.gitCommit` (full SHA)
--                         separate from `DeploymentArtifact.version`.
--   "workspace"           the WorkspaceDescriptor as a JSON document. Its
--                         `startingRevision` is the SAME commit as
--                         `pinnedRevision`; `OnboardingRecord.validate()`
--                         refuses a row carrying two different ones, which is
--                         the only place that contradiction is visible.
--   "completedBaselineId" the ProductBaseline whose human acceptance set
--                         `completed`. `completed` is a bare boolean with no
--                         evidence of its own, and this is the pointer that
--                         makes it checkable against `product_baseline`.
--
-- IDEMPOTENT / NON-DESTRUCTIVE. Three ADD COLUMNs, all nullable, no default:
-- existing rows are untouched and read back with all three fields NULL. No
-- UPDATE, no DELETE, no table rebuild, no index rebuild. Applied once, inside
-- the surrounding transaction, by the migration runner rather than by hand.
ALTER TABLE "onboarding_record" ADD COLUMN "pinnedRevision" text;
ALTER TABLE "onboarding_record" ADD COLUMN "workspace" text;
ALTER TABLE "onboarding_record" ADD COLUMN "completedBaselineId" text;

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261012213045000', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261012213045000', "timestamp" = now();

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
-- Dropping these three columns discards the ONLY durable record of which
-- commit a product is pinned to and where its code lives. Run only to return a
-- database to its pre-migration shape, then re-apply this migration instead.
--
-- WARNING: the `serverpod_migrations` version is rolled back LAST, after the
-- columns are gone. The reverse order would leave a database that claims to be
-- on this version while carrying the previous version's columns, which is a
-- state no `definition.sql` describes.
--
-- BEGIN;
--
-- ALTER TABLE "onboarding_record" DROP COLUMN "completedBaselineId";
-- ALTER TABLE "onboarding_record" DROP COLUMN "workspace";
-- ALTER TABLE "onboarding_record" DROP COLUMN "pinnedRevision";
--
-- DELETE FROM "serverpod_migrations" WHERE "module" = 'control_plane' AND "version" = '20261012213045000';
--
-- COMMIT;


COMMIT;