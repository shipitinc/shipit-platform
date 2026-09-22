enum AuditAction {
  create('create'),
  update('update'),
  transition('transition'),
  accept('accept'),
  reject('reject'),
  revoke('revoke'),
  rotate('rotate'),
  confirmHost('confirm_host'),
  checkCredential('check_credential'),
  proposeBaseline('propose_baseline'),
  verifyBaseline('verify_baseline'),
  requestApproval('request_approval'),
  resolveApproval('resolve_approval'),
  requireClarification('require_clarification'),
  answerClarification('answer_clarification'),
  requestLifecycle('request_lifecycle'),
  resolveLifecycle('resolve_lifecycle'),
  requestPolicy('request_policy'),
  resolvePolicy('resolve_policy'),
  revokePolicy('revoke_policy');

  const AuditAction(this.wire);

  final String wire;

  static AuditAction fromWire(String value) {
    return values.firstWhere(
      (e) => e.wire == value,
      orElse: () => throw ArgumentError('Unknown AuditAction wire: $value'),
    );
  }
}