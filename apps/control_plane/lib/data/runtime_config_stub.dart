/// Non-web implementation of the runtime configuration reader.
///
/// Selected on the Dart VM (tests, `dart run`) via the conditional import in
/// `client_provider.dart`, where no JavaScript host object exists.
String? readControlPlaneApi() => null;
