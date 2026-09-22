BEGIN;

--
-- ACTION ALTER TABLE
--
DROP INDEX "baseline_fact_id_unique";
CREATE UNIQUE INDEX "baseline_fact_id_unique" ON "baseline_fact" USING btree ("factId", "baselineId");

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20260922004754773', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260922004754773', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
