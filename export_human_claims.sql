SELECT section, claim, maturity, "evidenceRefsJson", "assumptionNote"
FROM baseline_fact
WHERE "baselineId" = 'bl-shipit-platform-2' AND provenance = 'human_provided';