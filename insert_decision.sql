INSERT INTO human_decision (
  "decisionId", "workItemId", "decisionType", status, question, "contextJson", "optionsJson", recommendation, blocking, "requestedAt", "updatedAt", "metadataJson"
) VALUES (
  'blappr-bl-shipit-platform-1',
  'product-baseline:shipit-platform',
  'product_decision',
  'pending',
  'Approve Product baseline bl-shipit-platform-1 (revision 1) for shipit-platform?',
  '{"workflowState": "baseline_review", "availableOptions": ["approve_baseline", "request_baseline_correction", "reject_baseline"]}',
  '[{"optionId": "approve_baseline", "label": "Approve baseline", "description": "Accept this exact baseline revision as the authoritative Product understanding.", "recommended": true}, {"optionId": "request_baseline_correction", "label": "Request correction", "description": "Send the baseline back for a new proposed revision; does not accept.", "recommended": false}, {"optionId": "reject_baseline", "label": "Reject baseline", "description": "Reject this proposed baseline; does not accept.", "recommended": false}]',
  'approve_baseline',
  true,
  now(),
  now(),
  '{"routing": "product_baseline_approval", "productId": "shipit-platform", "baselineId": "bl-shipit-platform-1", "baselineRevision": 1, "contentHash": "a0c6eee7881a52ab05e04c6c7a26b862877e804763ff35bcf7da51555c1c442d", "contentHashVersion": 3}'
);