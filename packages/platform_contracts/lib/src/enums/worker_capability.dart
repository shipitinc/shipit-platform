/// Bounded, provider-neutral worker capability tokens. Capability matching is
/// deterministic: a worker that lacks a required token cannot take the job.
/// Tokens are additive; removing one is a breaking schema change.
enum WorkerCapability {
  linux,
  macos,
  docker,
  flutter,
  web,
  android,
  ios,
  xcode,
  gpu,
  penpotRead,
  penpotWrite,
  visualDesign,
  designReview,
  git,
}
