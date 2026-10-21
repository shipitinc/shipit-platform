SELECT "provenance", count(*)
FROM baseline_fact
WHERE "baselineId" IN ('bl-shipit-platform-1', 'bl-shipit-platform-2')
GROUP BY "baselineId", "provenance"
ORDER BY "baselineId", "provenance";