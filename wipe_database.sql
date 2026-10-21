DELETE FROM baseline_fact WHERE "baselineId" LIKE 'bl-shipit-platform-%';
DELETE FROM human_decision WHERE "workItemId" = 'product-baseline:shipit-platform';
DELETE FROM product_baseline WHERE "productId" = 'shipit-platform';
DELETE FROM product WHERE "productId" = 'shipit-platform';
DELETE FROM repository_reference WHERE "productId" = 'shipit-platform';
DELETE FROM onboarding_record WHERE "productId" = 'shipit-platform';