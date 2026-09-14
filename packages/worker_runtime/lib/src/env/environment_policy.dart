import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

/// Explicit policy for building the execution environment of an isolated
/// worker run. Nothing is inherited wholesale: only allowlisted names are
/// copied from the host env, and every override is a non-secret literal.
///
/// Precedence (lowest to highest): allowlisted host variables, request-declared
/// [WorkerExecutionRequest.environment], this policy's own explicit values.
@immutable
class EnvironmentPolicy {
  const EnvironmentPolicy({
    this.inheritAllowlist = const [],
    this.explicit = const {},
  });

  /// Host environment variable names the worker may copy into an execution.
  final List<String> inheritAllowlist;

  /// Fixed, non-secret variables every execution may rely on.
  final Map<String, String> explicit;

  Map<String, String> resolve(
    WorkerExecutionRequest request, {
    Map<String, String>? hostEnv,
  }) {
    final resolved = <String, String>{};
    final host = hostEnv ?? const <String, String>{};

    final allowlisted = <String>{...?request.envAllowlist, ...inheritAllowlist};
    for (final name in allowlisted) {
      final value = host[name];
      if (value != null) resolved[name] = value;
    }

    resolved.addAll(request.environment ?? const {});
    resolved.addAll(explicit);
    return resolved;
  }
}
