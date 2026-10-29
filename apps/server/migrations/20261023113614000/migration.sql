BEGIN;

-- Add declared_owned_paths column to design_revision table
-- This column stores the owned paths declared by the designer at design/plan time
-- Per decision 7d2a81f0, the grant is recorded at design/plan time and carried on the approval decision

ALTER TABLE "design_revision"
ADD COLUMN IF NOT EXISTS "declared_owned_paths" TEXT[] DEFAULT '{}' NOT NULL;

-- Index for querying revisions by declared owned paths
CREATE INDEX IF NOT EXISTS "design_revision_declared_owned_paths_idx"
ON "design_revision" USING gin ("declared_owned_paths");

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261023113614000', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261023113614000', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
