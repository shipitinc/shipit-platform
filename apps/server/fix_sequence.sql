BEGIN;

-- Fix the sequence name for product_credential.id
ALTER SEQUENCE "repository_credential_id_seq" RENAME TO "product_credential_id_seq";

-- Fix the primary key index name
ALTER INDEX "product_credential_pkey" RENAME TO "product_credential_pkey_new";
ALTER INDEX "product_credential_pkey_new" RENAME TO "product_credential_pkey";

-- Update the column default to use the new sequence
ALTER TABLE "product_credential" ALTER COLUMN "id" SET DEFAULT nextval('product_credential_id_seq'::regclass);

COMMIT;
