BEGIN;

--
-- SHIPIT CONTROL PLANE: partial unique index enforcing one active credential
-- per repository (documented deviation - a partial index is not expressible in
-- Serverpod models, so the generator's diff source cannot produce it).
--
-- WHY THIS MIGRATION EXISTS. This is the chain-path counterpart of the same
-- index in `tool/schema_bootstrap.sql`, and it is the half that reaches
-- deployed databases. Serverpod applies exactly ONE artifact to a database
-- with no recorded migration version: the LATEST `definition.sql`
-- (serverpod-3.4.13 `migration_manager.dart` `_loadMigrationSQL`: when
-- `fromVersion == null` it reads `definitionSql`; only the `else` branch walks
-- `migration.sql` files). A chain-migrated database replays `migration.sql`
-- instead, so the bootstrap copy alone enforced this invariant on fresh and CI
-- databases only. See `tool/schema_bootstrap.sql` for the full rationale.
--
-- The statement below is byte-identical to the bootstrap copy, and both are
-- `IF NOT EXISTS`: a database that was created fresh and has since had the
-- bootstrap applied already carries this index, and replaying this migration
-- onto it must be a no-op rather than an error.
--
-- It is NOT in any generated `definition.sql`, deliberately, including this
-- directory's own. `serverpod create-migration` rewrites `definition.sql`
-- verbatim from the Dart models (serverpod_cli-3.4.13 `generator.dart:543-581`),
-- so a hand edit there is silently erased by the next regeneration. The object
-- lives here and in the bootstrap asset instead, and
-- `tool/verify_schema_bootstrap.sh` asserts the two agree.
--
-- WHY THE VERSION ROWS COME LAST. `serverpod create-migration` emits the DDL
-- first and the `serverpod_migrations` rows after it, and this file keeps that
-- order: the version a database records must never be the last durable effect
-- of a migration that did not complete. (Both are inside this file's
-- `BEGIN`/`COMMIT`, so a failure rolls both back regardless — but the shipped
-- shape is the one a reviewer can diff against any generated migration.)
--
-- PREREQUISITE, NOT SATISFIED BY THIS FILE. `CREATE UNIQUE INDEX` fails if this
-- database already holds two non-revoked credentials for one repository. Audit
-- before deploying. Note the double quotes: the column is `"repositoryId"`, and
-- an unquoted `repositoryId` folds to `repositoryid` and errors instead of
-- reporting:
--
--   SELECT "repositoryId", count(*)
--     FROM product_credential
--    WHERE "status" <> 'revoked'
--    GROUP BY "repositoryId"
--   HAVING count(*) > 1;
--
-- Any row returned must be reconciled by a human first. This migration does not
-- delete or rewrite credential rows to make itself applicable; it fails loudly
-- and rolls back instead.
--
CREATE UNIQUE INDEX IF NOT EXISTS "product_credential_active_repository_unique"
    ON "product_credential" USING btree ("repositoryId")
    WHERE ("status" <> 'revoked');

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261006150645000', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261006150645000', "timestamp" = now();

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
-- To rollback this migration, run the following:
--
-- BEGIN;
--
-- DROP INDEX IF EXISTS "product_credential_active_repository_unique";
--
-- -- Migration version rollback for control_plane
-- DELETE FROM "serverpod_migrations" WHERE "module" = 'control_plane' AND "version" = '20261006150645000';
--
-- COMMIT;


COMMIT;
