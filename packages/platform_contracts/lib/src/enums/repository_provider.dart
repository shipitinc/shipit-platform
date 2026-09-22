/// Host that owns a [RepositoryReference] (checkpoint 006 §8). Storage is
/// provenance only — product identity never derives from a path/URL/provider.
enum RepositoryProvider {
  github,
  gitlab,

  /// Any other host reachable over SSH, including self-hosted servers with no
  /// provider-specific affordances (ADR 0018). SSH is the only credential
  /// mechanism portable across every such host, so this value must exist for
  /// the "any git host" requirement to be honest.
  ssh,

  local;

  static RepositoryProvider fromWire(String value) =>
      RepositoryProvider.values.firstWhere(
        (p) => p.name == value,
        orElse: () =>
            throw FormatException('Unknown repository provider: $value'),
      );

  String toWire() => name;
}
