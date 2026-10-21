SELECT "baselineId", "provenance", claim
FROM baseline_fact
WHERE "baselineId" IN ('bl-shipit-platform-1', 'bl-shipit-platform-2')
ORDER BY "baselineId", "provenance", "claim";