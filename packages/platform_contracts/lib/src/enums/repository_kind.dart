/// Kinds of repositories a Product may own (checkpoint 006 §8). One Product
/// → one or more of these; the field is authoritative attribution.
enum RepositoryKind {
  monorepo,
  frontend,
  backend,
  infrastructure,
  library,
  app;

  static RepositoryKind fromWire(String value) =>
      RepositoryKind.values.firstWhere(
        (k) => k.name == value,
        orElse: () => throw FormatException('Unknown repository kind: $value'),
      );

  String toWire() => name;
}
