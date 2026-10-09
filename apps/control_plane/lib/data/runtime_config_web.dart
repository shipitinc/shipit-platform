import 'dart:js_interop';

/// Web implementation of the runtime configuration reader.
///
/// Selected on JavaScript/Wasm targets via the conditional import in
/// `client_provider.dart`. Reads `window.SHIPIT_CONFIG.CONTROL_PLANE_API`, which
/// `config.js` (rendered from `docker/config.js.template`) defines at container
/// startup, so the API base URL can be set without rebuilding the Flutter bundle.
///
/// Returns null when the host object is absent or carries no usable value, which
/// lets `client_provider.dart` fall back to its build-time default.
String? readControlPlaneApi() => readRuntimeConfigValue('CONTROL_PLANE_API');

/// Web implementation of the generic runtime-configuration reader.
///
/// The same `window.SHIPIT_CONFIG` object [readControlPlaneApi] reads, exposed
/// by key rather than as a named accessor so a deployment can add configuration
/// without a matching Dart function. `key` is deliberately ignored on the stub
/// side, where there is nothing to read.
///
/// NOTE FOR THE OWNER OF `docker/config.js.template`: that file enumerates the
/// keys it publishes. A key this reader asks for is only populated if the
/// template also publishes it — otherwise this returns null and the caller uses
/// its build-time `--dart-define`. See `operator_attestation.dart`.
String? readRuntimeConfigValue(String key) {
  final config = shipitConfig;
  if (config == null) return null;
  return config[key]?.toDart;
}

@JS('SHIPIT_CONFIG')
external SHIPitConfig? get shipitConfig;

extension type SHIPitConfig._(JSObject _) implements JSObject {
  external JSString? operator [](String key);
}
