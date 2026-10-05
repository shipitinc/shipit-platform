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
String? readControlPlaneApi() {
  final config = shipitConfig;
  if (config == null) return null;
  return config['CONTROL_PLANE_API']?.toDart;
}

@JS('SHIPIT_CONFIG')
external SHIPITConfig? get shipitConfig;

extension type SHIPITConfig._(JSObject _) implements JSObject {
  external JSString? operator [](String key);
}
