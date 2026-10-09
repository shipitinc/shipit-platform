/// Non-web implementation of the runtime configuration reader.
///
/// Selected on the Dart VM (tests, `dart run`) via the conditional import in
/// `client_provider.dart`, where no JavaScript host object exists.
String? readControlPlaneApi() => null;

/// Non-web implementation of the generic runtime-configuration reader.
///
/// Same reason as [readControlPlaneApi]: there is no JavaScript host object on
/// this target, so `window.SHIPIT_CONFIG` cannot exist. Returns null so callers
/// fall back to their build-time `--dart-define` value.
String? readRuntimeConfigValue(String key) => null;
