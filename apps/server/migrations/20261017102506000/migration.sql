BEGIN;

--
-- product_qa_contract_spec -- the QA contract a PRODUCT DECLARES, made durable.
--
-- WHY THIS TABLE IS BEING ADDED, stated as the defect it closes.
--
-- `ProductManifest.contracts.qaContract` (`QAContractSpec`) has existed as a
-- type for the whole life of the platform, and it was never reachable. Its one
-- production construction site wrote it EMPTY
-- (`product_registry_endpoints.dart`, `QAContractSpec(gates: const [])`) and
-- the value was then DISCARDED: `registerProductWithManifest` recorded only
-- `manifestVersion`, and `PostgresProductRegistryStore.saveProduct` writes
-- productId, name, description, manifestVersion, state, createdAt, updatedAt and
-- version -- `contracts` appears in that file only in an import.
--
-- So no product could ever declare a QA contract, and every work item the
-- defect-triage lane did not create ran and could never be recorded:
-- `GuardConditions.qaContractExists()` refuses
-- `agentExecuting -> agentCompleted` on a NULL CHECK of
-- `context['qaContractId']`, and nothing on those two paths ever set one.
-- Measured across all 14 work items on 2026-10-17 the correlation was perfect:
-- 10/10 `defect-DEF-*` items carried a `qaContractId`; 0/4
-- `design-remediation-*` / `WI-feature-*` items did.
--
-- WHAT THIS MIGRATION DOES NOT DO. It does not widen, weaken or bypass that
-- guard: `work_item_transitions.dart` and `guard_conditions.dart` are untouched
-- by this change, and the guard is exactly as strict as it was. It does not
-- declare a QA contract for any product -- declaring one is a human act taken
-- through `createProduct` with a manifest. It does not move, repair or complete
-- any work item; the three items stranded in `agentExecuting` need a human
-- operator transition after their contracts exist, because `agentExecuting` has
-- no edge to anything but `agentCompleted` and `agentFailed`.
--
-- THIS MIGRATION IS PURELY ADDITIVE. It creates one table and one index. It
-- touches no existing table, adds no column to one, drops nothing, renames
-- nothing and rewrites no row. Every existing row of every existing table reads
-- back exactly as it did before, which is the backward-compatibility property
-- that makes it safe to run against a database this repository cannot recreate.
--
-- WHY A SEPARATE TABLE RATHER THAN A COLUMN ON `product`.
--
--   * `qa_contract` is keyed by `contractId` and `saveQAContract` is
--     `ON CONFLICT ("contractId") DO UPDATE`. A DECLARATION is a per-product
--     default with no id of its own; storing it in that table would mean either
--     minting a fake `contractId` into the namespace real contracts live in, or
--     making the column unique on a second key `ON CONFLICT` does not arbitrate.
--     Both put a row into the one table every gate evaluator reads.
--   * The shape is different, not merely smaller: a declaration has no
--     `workItemCategory`, no `createdAt` and no provenance, because none of
--     those is a property of a product. Reading one back through
--     `QAContract.fromJson` would mean inventing all three.
--
-- `gatesJson` is `text`, not `jsonb`, matching `qa_contract."gatesJson"`. Both
-- stores decode their JSON columns explicitly and name the column in any
-- failure, and matching the existing table keeps one convention for QA JSON
-- rather than two.
--

--
-- Class ProductQAContractSpecRow as table product_qa_contract_spec
--
CREATE TABLE IF NOT EXISTS "product_qa_contract_spec" (
    "id" bigserial PRIMARY KEY,
    "productId" text NOT NULL,
    "gatesJson" text NOT NULL,
    "manifestVersion" text,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL,
    "version" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS "product_qa_contract_spec_pkey" ON "product_qa_contract_spec" USING btree ("id");
CREATE UNIQUE INDEX IF NOT EXISTS "product_qa_contract_spec_product_unique" ON "product_qa_contract_spec" USING btree ("productId");


--
-- THE SHAPE IS ASSERTED, NOT ASSUMED.
--
-- `IF NOT EXISTS` makes a re-run a no-op. It also makes this statement agree
-- with a pre-existing table that happens to share the NAME while saying
-- something else entirely -- which is how a migration silently becomes a no-op
-- and leaves the deployment missing the column it wrote for. This block reads
-- the table back and refuses, before anything is committed, if the columns are
-- not the ones the Dart store above binds parameters to. `IF NOT EXISTS` on the
-- indexes is not checked the same way, because an index on this table can only
-- be wrong about a column this block has already refused.
--
DO $$
DECLARE
    observed text;
BEGIN
    SELECT string_agg("column_name", ',' ORDER BY "ordinal_position")
      INTO observed
      FROM information_schema."columns"
     WHERE "table_schema" = current_schema()
       AND "table_name" = 'product_qa_contract_spec';

    IF observed IS DISTINCT FROM 'id,productId,gatesJson,manifestVersion,createdAt,updatedAt,version' THEN
        RAISE EXCEPTION
            'product_qa_contract_spec exists with columns [%], but migration 20261017102506000 binds '
            'id,productId,gatesJson,manifestVersion,createdAt,updatedAt,version. '
            'The IF NOT EXISTS guard above made the CREATE a no-op, so this '
            'migration would otherwise have recorded a version on a database '
            'whose table is a different shape. Nothing was committed.',
            COALESCE(observed, '<no such table>');
    END IF;
END $$;

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261017102506000', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261017102506000', "timestamp" = now();

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
-- This drops the table and therefore EVERY QA contract a product has declared
-- through it. Work items already provisioned from one of those declarations keep
-- their `work_item.qaContractId` pointing at a `qa_contract` row that still
-- exists -- `qa_contract` is untouched here -- so a rollback does NOT break the
-- completion guard for items already stamped. It DOES mean no product can be
-- provisioned for again until this migration is re-applied and every product
-- re-declares its gates: there is nowhere else a declaration is stored.
--
-- There is no way to roll this back without losing the declarations, which is
-- the honest shape of a change that creates the only place a declaration can
-- live. Every statement is commented out, so nothing here executes by accident.
--

-- -- DOWN SCRIPT START
-- BEGIN;
-- -- Only the two objects this migration created, and only after the data is
-- -- gone, so the index cannot outlive its table.
-- DROP TABLE IF EXISTS "product_qa_contract_spec";
-- -- Migration version rollback for control_plane.
-- DELETE FROM "serverpod_migrations"
--  WHERE "module" = 'control_plane' AND "version" = '20261017102506000';
-- COMMIT;
-- -- DOWN SCRIPT END


COMMIT;
