/// Lifecycle of a [RepositoryCredential] (ADR 0018).
///
/// Status is only ever advanced by a **proven** result. There is deliberately
/// no "assumed working" value: a credential is either verified by a real
/// connection attempt at a recorded time, or it is not.
enum CredentialStatus {
  /// Keypair generated locally. The public half is available to install; the
  /// credential has never successfully reached the repository.
  generated('generated'),

  /// A connectivity check against the real host with the real key succeeded.
  /// [RepositoryCredential.lastVerifiedAt] records when.
  verified('verified'),

  /// The most recent connectivity check failed. Distinct from [generated]:
  /// this credential worked before, or was expected to.
  failing('failing'),

  /// Withdrawn. Retained so the historical record stays readable, never
  /// deleted.
  revoked('revoked');

  const CredentialStatus(this.wire);

  final String wire;

  /// Whether this credential may currently be used to reach the repository.
  bool get isUsable => this == CredentialStatus.verified;

  static CredentialStatus fromWire(String value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => throw FormatException('Unknown credential status: $value'),
  );
}

/// Trust state of the SSH host key for a repository's host (ADR 0018).
///
/// ShipIt refuses to connect to a host it has never seen. The operator is
/// shown the host key fingerprint and must confirm it out of band — ShipIt
/// cannot verify a host on the operator's behalf and does not claim to.
enum HostKeyStatus {
  /// Never seen. Connection is refused until a human confirms the fingerprint.
  unknown('unknown'),

  /// A human confirmed this exact fingerprint.
  confirmed('confirmed'),

  /// A fingerprint was recorded before and the host now presents a different
  /// one. Fails closed: this is indistinguishable from an interception.
  changed('changed');

  const HostKeyStatus(this.wire);

  final String wire;

  /// Whether a connection may be attempted at all.
  bool get permitsConnection => this == HostKeyStatus.confirmed;

  static HostKeyStatus fromWire(String value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => throw FormatException('Unknown host key status: $value'),
  );
}
