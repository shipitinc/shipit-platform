BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "defect" ADD COLUMN "productId" text;

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260930022649505', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260930022649505', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
