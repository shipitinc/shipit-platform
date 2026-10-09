/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: no_leading_underscores_for_library_prefixes
// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:serverpod_test/serverpod_test.dart' as _i1;
import 'package:serverpod/serverpod.dart' as _i2;
import 'dart:async' as _i3;
import 'package:control_plane_server/src/generated/minted_credential_view.dart'
    as _i4;
import 'package:control_plane_server/src/generated/credential_access_verification_view.dart'
    as _i5;
import 'package:control_plane_server/src/generated/overview.dart' as _i6;
import 'package:control_plane_server/src/generated/work_item_view.dart' as _i7;
import 'package:control_plane_server/src/generated/decision_view.dart' as _i8;
import 'package:control_plane_server/src/generated/human_direction_view.dart'
    as _i9;
import 'package:control_plane_server/src/generated/human_direction_attachment_view.dart'
    as _i10;
import 'package:control_plane_server/src/generated/feature_request_summary_view.dart'
    as _i11;
import 'package:control_plane_server/src/generated/product_view.dart' as _i12;
import 'package:control_plane_server/src/generated/product_summary_view.dart'
    as _i13;
import 'package:control_plane_server/src/generated/product_detail_view.dart'
    as _i14;
import 'package:control_plane_server/src/generated/product_context_view.dart'
    as _i15;
import 'package:platform_contracts/src/types/baseline_fact.dart' as _i16;
import 'package:control_plane_server/src/generated/standing_policy_view.dart'
    as _i17;
import 'package:control_plane_server/src/generated/clarification_view.dart'
    as _i18;
import 'package:control_plane_server/src/generated/job_summary_view.dart'
    as _i19;
import 'package:control_plane_server/src/generated/work_item_detail_view.dart'
    as _i20;
import 'package:control_plane_server/src/generated/resolve_decision_view.dart'
    as _i21;
import 'package:control_plane_server/src/generated/protocol.dart';
import 'package:control_plane_server/src/generated/endpoints.dart';
export 'package:serverpod_test/serverpod_test_public_exports.dart';

/// Creates a new test group that takes a callback that can be used to write tests.
/// The callback has two parameters: `sessionBuilder` and `endpoints`.
/// `sessionBuilder` is used to build a `Session` object that represents the server state during an endpoint call and is used to set up scenarios.
/// `endpoints` contains all your Serverpod endpoints and lets you call them:
/// ```dart
/// withServerpod('Given Example endpoint', (sessionBuilder, endpoints) {
///   test('when calling `hello` then should return greeting', () async {
///     final greeting = await endpoints.example.hello(sessionBuilder, 'Michael');
///     expect(greeting, 'Hello Michael');
///   });
/// });
/// ```
///
/// **Configuration options**
///
/// [applyMigrations] Whether pending migrations should be applied when starting Serverpod. Defaults to `true`
///
/// [enableSessionLogging] Whether session logging should be enabled. Defaults to `false`
///
/// [rollbackDatabase] Options for when to rollback the database during the test lifecycle.
/// By default `withServerpod` does all database operations inside a transaction that is rolled back after each `test` case.
/// Just like the following enum describes, the behavior of the automatic rollbacks can be configured:
/// ```dart
/// /// Options for when to rollback the database during the test lifecycle.
/// enum RollbackDatabase {
///   /// After each test. This is the default.
///   afterEach,
///
///   /// After all tests.
///   afterAll,
///
///   /// Disable rolling back the database.
///   disabled,
/// }
/// ```
///
/// [runMode] The run mode that Serverpod should be running in. Defaults to `test`.
///
/// [serverpodLoggingMode] The logging mode used when creating Serverpod. Defaults to `ServerpodLoggingMode.normal`
///
/// [serverpodStartTimeout] The timeout to use when starting Serverpod, which connects to the database among other things. Defaults to `Duration(seconds: 30)`.
///
/// [testServerOutputMode] Options for controlling test server output during test execution. Defaults to `TestServerOutputMode.normal`.
/// ```dart
/// /// Options for controlling test server output during test execution.
/// enum TestServerOutputMode {
///   /// Default mode - only stderr is printed (stdout suppressed).
///   /// This hides normal startup/shutdown logs while preserving error messages.
///   normal,
///
///   /// All logging - both stdout and stderr are printed.
///   /// Useful for debugging when you need to see all server output.
///   verbose,
///
///   /// No logging - both stdout and stderr are suppressed.
///   /// Completely silent mode, useful when you don't want any server output.
///   silent,
/// }
/// ```
///
/// [configOverride] A function to override the server configuration. This function is called with
/// the default server configuration after it is loaded from the config/ directory
/// and before it is used to start the server. Use this to override particular
/// settings in the server configuration.
///
/// [testGroupTagsOverride] By default Serverpod test tools tags the `withServerpod` test group with `"integration"`.
/// This is to provide a simple way to only run unit or integration tests.
/// This property allows this tag to be overridden to something else. Defaults to `['integration']`.
///
/// [experimentalFeatures] Optionally specify experimental features. See [Serverpod] for more information.
@_i1.isTestGroup
void withServerpod(
  String testGroupName,
  _i1.TestClosure<TestEndpoints> testClosure, {
  bool? applyMigrations,
  _i2.ServerpodConfig Function(_i2.ServerpodConfig)? configOverride,
  bool? enableSessionLogging,
  _i2.ExperimentalFeatures? experimentalFeatures,
  _i1.RollbackDatabase? rollbackDatabase,
  String? runMode,
  _i2.RuntimeParametersListBuilder? runtimeParametersBuilder,
  _i2.ServerpodLoggingMode? serverpodLoggingMode,
  Duration? serverpodStartTimeout,
  List<String>? testGroupTagsOverride,
  _i1.TestServerOutputMode? testServerOutputMode,
}) {
  _i1.buildWithServerpod<_InternalTestEndpoints>(
    testGroupName,
    _i1.TestServerpod(
      testEndpoints: _InternalTestEndpoints(),
      endpoints: Endpoints(),
      serializationManager: Protocol(),
      runMode: runMode,
      applyMigrations: applyMigrations,
      isDatabaseEnabled: true,
      serverpodLoggingMode: serverpodLoggingMode,
      testServerOutputMode: testServerOutputMode,
      experimentalFeatures: experimentalFeatures,
      configOverride: configOverride,
      runtimeParametersBuilder: runtimeParametersBuilder,
    ),
    maybeRollbackDatabase: rollbackDatabase,
    maybeEnableSessionLogging: enableSessionLogging,
    maybeTestGroupTagsOverride: testGroupTagsOverride,
    maybeServerpodStartTimeout: serverpodStartTimeout,
    maybeTestServerOutputMode: testServerOutputMode,
  )(testClosure);
}

class TestEndpoints {
  late final _CredentialEndpoints credentialEndpoints;

  late final _DefectEndpoints defectEndpoints;

  late final _ExecutionEndpoints executionEndpoints;

  late final _HealthEndpoints healthEndpoints;

  late final _HomeEndpoints homeEndpoints;

  late final _HumanDirectionEndpoints humanDirectionEndpoints;

  late final _IntakeEndpoints intakeEndpoints;

  late final _ProductRegistryEndpoints productRegistryEndpoints;

  late final _ProviderHealthEndpoints providerHealthEndpoints;

  late final _SchedulerEndpoints schedulerEndpoints;

  late final _WorkerEndpoints workerEndpoints;

  late final _WorkflowEndpoints workflowEndpoints;
}

class _InternalTestEndpoints extends TestEndpoints
    implements _i1.InternalTestEndpoints {
  @override
  void initialize(
    _i2.SerializationManager serializationManager,
    _i2.EndpointDispatch endpoints,
  ) {
    credentialEndpoints = _CredentialEndpoints(
      endpoints,
      serializationManager,
    );
    defectEndpoints = _DefectEndpoints(
      endpoints,
      serializationManager,
    );
    executionEndpoints = _ExecutionEndpoints(
      endpoints,
      serializationManager,
    );
    healthEndpoints = _HealthEndpoints(
      endpoints,
      serializationManager,
    );
    homeEndpoints = _HomeEndpoints(
      endpoints,
      serializationManager,
    );
    humanDirectionEndpoints = _HumanDirectionEndpoints(
      endpoints,
      serializationManager,
    );
    intakeEndpoints = _IntakeEndpoints(
      endpoints,
      serializationManager,
    );
    productRegistryEndpoints = _ProductRegistryEndpoints(
      endpoints,
      serializationManager,
    );
    providerHealthEndpoints = _ProviderHealthEndpoints(
      endpoints,
      serializationManager,
    );
    schedulerEndpoints = _SchedulerEndpoints(
      endpoints,
      serializationManager,
    );
    workerEndpoints = _WorkerEndpoints(
      endpoints,
      serializationManager,
    );
    workflowEndpoints = _WorkflowEndpoints(
      endpoints,
      serializationManager,
    );
  }
}

class _CredentialEndpoints {
  _CredentialEndpoints(
    this._endpointDispatch,
    this._serializationManager,
  );

  final _i2.EndpointDispatch _endpointDispatch;

  final _i2.SerializationManager _serializationManager;

  _i3.Future<_i4.MintedCredentialView> generate(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
    required String repositoryId,
    String? credentialId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'credentialEndpoints',
            method: 'generate',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'credentialEndpoints',
          methodName: 'generate',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'repositoryId': repositoryId,
            'credentialId': credentialId,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i4.MintedCredentialView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i5.CredentialAccessVerificationView> verifyAccess(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
    required String repositoryId,
    required String hostKeyFingerprint,
    required String confirmedBy,
    String? checkedBy,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'credentialEndpoints',
            method: 'verifyAccess',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'credentialEndpoints',
          methodName: 'verifyAccess',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'repositoryId': repositoryId,
            'hostKeyFingerprint': hostKeyFingerprint,
            'confirmedBy': confirmedBy,
            'checkedBy': checkedBy,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i5.CredentialAccessVerificationView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }
}

class _DefectEndpoints {
  _DefectEndpoints(
    this._endpointDispatch,
    this._serializationManager,
  );

  final _i2.EndpointDispatch _endpointDispatch;

  final _i2.SerializationManager _serializationManager;

  _i3.Future<Map<String, dynamic>> create(
    _i1.TestSessionBuilder sessionBuilder, {
    required String title,
    required String description,
    String? expectedBehavior,
    String? reproductionSteps,
    required String severity,
    String? intakeCategory,
    required String productId,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? clientContextJson,
    required String reporter,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'defectEndpoints',
            method: 'create',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'defectEndpoints',
          methodName: 'create',
          parameters: _i1.testObjectToJson({
            'title': title,
            'description': description,
            'expectedBehavior': expectedBehavior,
            'reproductionSteps': reproductionSteps,
            'severity': severity,
            'intakeCategory': intakeCategory,
            'productId': productId,
            'affectedWorkItemId': affectedWorkItemId,
            'affectedRunId': affectedRunId,
            'clientContextJson': clientContextJson,
            'reporter': reporter,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> list(
    _i1.TestSessionBuilder sessionBuilder, {
    String? productId,
    String? status,
    String? classification,
    int? limit,
    int? offset,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'defectEndpoints',
            method: 'list',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'defectEndpoints',
          methodName: 'list',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'status': status,
            'classification': classification,
            'limit': limit,
            'offset': offset,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> inspect(
    _i1.TestSessionBuilder sessionBuilder, {
    required String defectId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'defectEndpoints',
            method: 'inspect',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'defectEndpoints',
          methodName: 'inspect',
          parameters: _i1.testObjectToJson({'defectId': defectId}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> addEvidence(
    _i1.TestSessionBuilder sessionBuilder, {
    required String defectId,
    required String kind,
    String? description,
    String? artifactId,
    String? contentHash,
    String? sourceRef,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'defectEndpoints',
            method: 'addEvidence',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'defectEndpoints',
          methodName: 'addEvidence',
          parameters: _i1.testObjectToJson({
            'defectId': defectId,
            'kind': kind,
            'description': description,
            'artifactId': artifactId,
            'contentHash': contentHash,
            'sourceRef': sourceRef,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> requestClarification(
    _i1.TestSessionBuilder sessionBuilder, {
    required String defectId,
    required String question,
    required String reason,
    required String triageJobId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'defectEndpoints',
            method: 'requestClarification',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'defectEndpoints',
          methodName: 'requestClarification',
          parameters: _i1.testObjectToJson({
            'defectId': defectId,
            'question': question,
            'reason': reason,
            'triageJobId': triageJobId,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> answerClarification(
    _i1.TestSessionBuilder sessionBuilder, {
    required String clarificationId,
    required String answer,
    required String answeredBy,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'defectEndpoints',
            method: 'answerClarification',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'defectEndpoints',
          methodName: 'answerClarification',
          parameters: _i1.testObjectToJson({
            'clarificationId': clarificationId,
            'answer': answer,
            'answeredBy': answeredBy,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> verifyFix(
    _i1.TestSessionBuilder sessionBuilder, {
    required String defectId,
    required String choice,
    String? rationale,
    required String decider,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'defectEndpoints',
            method: 'verifyFix',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'defectEndpoints',
          methodName: 'verifyFix',
          parameters: _i1.testObjectToJson({
            'defectId': defectId,
            'choice': choice,
            'rationale': rationale,
            'decider': decider,
            'signature': signature,
            'publicKey': publicKey,
            'algorithm': algorithm,
            'signedAt': signedAt,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }
}

class _ExecutionEndpoints {
  _ExecutionEndpoints(
    this._endpointDispatch,
    this._serializationManager,
  );

  final _i2.EndpointDispatch _endpointDispatch;

  final _i2.SerializationManager _serializationManager;

  _i3.Future<Map<String, dynamic>> list(
    _i1.TestSessionBuilder sessionBuilder, {
    String? workItemId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'executionEndpoints',
            method: 'list',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'executionEndpoints',
          methodName: 'list',
          parameters: _i1.testObjectToJson({'workItemId': workItemId}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> inspect(
    _i1.TestSessionBuilder sessionBuilder, {
    required String executionId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'executionEndpoints',
            method: 'inspect',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'executionEndpoints',
          methodName: 'inspect',
          parameters: _i1.testObjectToJson({'executionId': executionId}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }
}

class _HealthEndpoints {
  _HealthEndpoints(
    this._endpointDispatch,
    this._serializationManager,
  );

  final _i2.EndpointDispatch _endpointDispatch;

  final _i2.SerializationManager _serializationManager;

  _i3.Future<Map<String, dynamic>> health(
    _i1.TestSessionBuilder sessionBuilder,
  ) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'healthEndpoints',
            method: 'health',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'healthEndpoints',
          methodName: 'health',
          parameters: _i1.testObjectToJson({}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }
}

class _HomeEndpoints {
  _HomeEndpoints(
    this._endpointDispatch,
    this._serializationManager,
  );

  final _i2.EndpointDispatch _endpointDispatch;

  final _i2.SerializationManager _serializationManager;

  _i3.Future<_i6.Overview> overview(
    _i1.TestSessionBuilder sessionBuilder,
  ) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'homeEndpoints',
            method: 'overview',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'homeEndpoints',
          methodName: 'overview',
          parameters: _i1.testObjectToJson({}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i6.Overview>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<List<_i7.WorkItemView>> listWorkItems(
    _i1.TestSessionBuilder sessionBuilder, {
    String? state,
    String? productId,
    int? limit,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'homeEndpoints',
            method: 'listWorkItems',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'homeEndpoints',
          methodName: 'listWorkItems',
          parameters: _i1.testObjectToJson({
            'state': state,
            'productId': productId,
            'limit': limit,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<List<_i7.WorkItemView>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<List<_i8.DecisionView>> recentDecisions(
    _i1.TestSessionBuilder sessionBuilder, {
    int? limit,
    int? offset,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'homeEndpoints',
            method: 'recentDecisions',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'homeEndpoints',
          methodName: 'recentDecisions',
          parameters: _i1.testObjectToJson({
            'limit': limit,
            'offset': offset,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<List<_i8.DecisionView>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<List<_i8.DecisionView>> pendingDecisions(
    _i1.TestSessionBuilder sessionBuilder, {
    int? limit,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'homeEndpoints',
            method: 'pendingDecisions',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'homeEndpoints',
          methodName: 'pendingDecisions',
          parameters: _i1.testObjectToJson({'limit': limit}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<List<_i8.DecisionView>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }
}

class _HumanDirectionEndpoints {
  _HumanDirectionEndpoints(
    this._endpointDispatch,
    this._serializationManager,
  );

  final _i2.EndpointDispatch _endpointDispatch;

  final _i2.SerializationManager _serializationManager;

  _i3.Future<_i9.HumanDirectionView> createDirection(
    _i1.TestSessionBuilder sessionBuilder, {
    required String directionType,
    required String targetType,
    String? targetId,
    required String title,
    required String description,
    String? contextJson,
    List<_i10.HumanDirectionAttachmentView>? attachments,
    String? createdBy,
    String? assignedTo,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'humanDirectionEndpoints',
            method: 'createDirection',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'humanDirectionEndpoints',
          methodName: 'createDirection',
          parameters: _i1.testObjectToJson({
            'directionType': directionType,
            'targetType': targetType,
            'targetId': targetId,
            'title': title,
            'description': description,
            'contextJson': contextJson,
            'attachments': attachments,
            'createdBy': createdBy,
            'assignedTo': assignedTo,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i9.HumanDirectionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<List<_i9.HumanDirectionView>> listDirectionsForTarget(
    _i1.TestSessionBuilder sessionBuilder, {
    required String targetType,
    required String targetId,
    String? status,
    int? limit,
    int? offset,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'humanDirectionEndpoints',
            method: 'listDirectionsForTarget',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'humanDirectionEndpoints',
          methodName: 'listDirectionsForTarget',
          parameters: _i1.testObjectToJson({
            'targetType': targetType,
            'targetId': targetId,
            'status': status,
            'limit': limit,
            'offset': offset,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<List<_i9.HumanDirectionView>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<List<_i9.HumanDirectionView>> listDirectionsByStatus(
    _i1.TestSessionBuilder sessionBuilder, {
    required String status,
    String? directionType,
    String? targetType,
    int? limit,
    int? offset,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'humanDirectionEndpoints',
            method: 'listDirectionsByStatus',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'humanDirectionEndpoints',
          methodName: 'listDirectionsByStatus',
          parameters: _i1.testObjectToJson({
            'status': status,
            'directionType': directionType,
            'targetType': targetType,
            'limit': limit,
            'offset': offset,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<List<_i9.HumanDirectionView>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i9.HumanDirectionView> readDirection(
    _i1.TestSessionBuilder sessionBuilder, {
    required String directionId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'humanDirectionEndpoints',
            method: 'readDirection',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'humanDirectionEndpoints',
          methodName: 'readDirection',
          parameters: _i1.testObjectToJson({'directionId': directionId}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i9.HumanDirectionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i9.HumanDirectionView> acknowledgeDirection(
    _i1.TestSessionBuilder sessionBuilder, {
    required String directionId,
    required String acknowledgedBy,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'humanDirectionEndpoints',
            method: 'acknowledgeDirection',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'humanDirectionEndpoints',
          methodName: 'acknowledgeDirection',
          parameters: _i1.testObjectToJson({
            'directionId': directionId,
            'acknowledgedBy': acknowledgedBy,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i9.HumanDirectionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i9.HumanDirectionView> startWorkingDirection(
    _i1.TestSessionBuilder sessionBuilder, {
    required String directionId,
    required String startedBy,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'humanDirectionEndpoints',
            method: 'startWorkingDirection',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'humanDirectionEndpoints',
          methodName: 'startWorkingDirection',
          parameters: _i1.testObjectToJson({
            'directionId': directionId,
            'startedBy': startedBy,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i9.HumanDirectionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i9.HumanDirectionView> completeDirection(
    _i1.TestSessionBuilder sessionBuilder, {
    required String directionId,
    required String completedBy,
    required String completionSummary,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'humanDirectionEndpoints',
            method: 'completeDirection',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'humanDirectionEndpoints',
          methodName: 'completeDirection',
          parameters: _i1.testObjectToJson({
            'directionId': directionId,
            'completedBy': completedBy,
            'completionSummary': completionSummary,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i9.HumanDirectionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i9.HumanDirectionView> rejectDirection(
    _i1.TestSessionBuilder sessionBuilder, {
    required String directionId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'humanDirectionEndpoints',
            method: 'rejectDirection',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'humanDirectionEndpoints',
          methodName: 'rejectDirection',
          parameters: _i1.testObjectToJson({
            'directionId': directionId,
            'rejectedBy': rejectedBy,
            'rejectionReason': rejectionReason,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i9.HumanDirectionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i9.HumanDirectionView> supersedeDirection(
    _i1.TestSessionBuilder sessionBuilder, {
    required String directionId,
    required String supersededByDirectionId,
    required String supersededBy,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'humanDirectionEndpoints',
            method: 'supersedeDirection',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'humanDirectionEndpoints',
          methodName: 'supersedeDirection',
          parameters: _i1.testObjectToJson({
            'directionId': directionId,
            'supersededByDirectionId': supersededByDirectionId,
            'supersededBy': supersededBy,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i9.HumanDirectionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }
}

class _IntakeEndpoints {
  _IntakeEndpoints(
    this._endpointDispatch,
    this._serializationManager,
  );

  final _i2.EndpointDispatch _endpointDispatch;

  final _i2.SerializationManager _serializationManager;

  _i3.Future<Map<String, dynamic>> createFeatureRequest(
    _i1.TestSessionBuilder sessionBuilder, {
    required String title,
    required String description,
    required String productId,
    required String reporter,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'intakeEndpoints',
            method: 'createFeatureRequest',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'intakeEndpoints',
          methodName: 'createFeatureRequest',
          parameters: _i1.testObjectToJson({
            'title': title,
            'description': description,
            'productId': productId,
            'reporter': reporter,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<List<_i11.FeatureRequestSummaryView>> listFeatureRequests(
    _i1.TestSessionBuilder sessionBuilder, {
    String? productId,
    String? state,
    int? limit,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'intakeEndpoints',
            method: 'listFeatureRequests',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'intakeEndpoints',
          methodName: 'listFeatureRequests',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'state': state,
            'limit': limit,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<List<_i11.FeatureRequestSummaryView>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }
}

class _ProductRegistryEndpoints {
  _ProductRegistryEndpoints(
    this._endpointDispatch,
    this._serializationManager,
  );

  final _i2.EndpointDispatch _endpointDispatch;

  final _i2.SerializationManager _serializationManager;

  _i3.Future<List<_i12.ProductView>> listProducts(
    _i1.TestSessionBuilder sessionBuilder,
  ) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'listProducts',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'listProducts',
          parameters: _i1.testObjectToJson({}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<List<_i12.ProductView>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<List<_i13.ProductSummaryView>> listProductSummaries(
    _i1.TestSessionBuilder sessionBuilder,
  ) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'listProductSummaries',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'listProductSummaries',
          parameters: _i1.testObjectToJson({}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<List<_i13.ProductSummaryView>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i14.ProductDetailView> productDetail(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'productDetail',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'productDetail',
          parameters: _i1.testObjectToJson({'productId': productId}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i14.ProductDetailView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i15.ProductContextView> productContext(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'productContext',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'productContext',
          parameters: _i1.testObjectToJson({'productId': productId}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i15.ProductContextView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i8.DecisionView> proposeBaseline(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
    required List<_i16.BaselineFact> facts,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'proposeBaseline',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'proposeBaseline',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'facts': facts,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i8.DecisionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i8.DecisionView> requestBaselineApproval(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
    required String baselineId,
    String? decisionId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'requestBaselineApproval',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'requestBaselineApproval',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'baselineId': baselineId,
            'decisionId': decisionId,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i8.DecisionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i8.DecisionView> requestLifecycleDecision(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
    required String action,
    required bool drainInFlight,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'requestLifecycleDecision',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'requestLifecycleDecision',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'action': action,
            'drainInFlight': drainInFlight,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i8.DecisionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i8.DecisionView> resolveLifecycleDecision(
    _i1.TestSessionBuilder sessionBuilder, {
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
    required bool noWorkInFlight,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'resolveLifecycleDecision',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'resolveLifecycleDecision',
          parameters: _i1.testObjectToJson({
            'decisionId': decisionId,
            'choice': choice,
            'decider': decider,
            'rationale': rationale,
            'signature': signature,
            'publicKey': publicKey,
            'algorithm': algorithm,
            'signedAt': signedAt,
            'noWorkInFlight': noWorkInFlight,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i8.DecisionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i8.DecisionView> requestPolicyAuthorisation(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
    required List<String> actions,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'requestPolicyAuthorisation',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'requestPolicyAuthorisation',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'actions': actions,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i8.DecisionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i17.StandingPolicyView?> resolvePolicyAuthorisation(
    _i1.TestSessionBuilder sessionBuilder, {
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'resolvePolicyAuthorisation',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'resolvePolicyAuthorisation',
          parameters: _i1.testObjectToJson({
            'decisionId': decisionId,
            'choice': choice,
            'decider': decider,
            'rationale': rationale,
            'signature': signature,
            'publicKey': publicKey,
            'algorithm': algorithm,
            'signedAt': signedAt,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i17.StandingPolicyView?>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i17.StandingPolicyView> revokeStandingPolicy(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
    required String policyId,
    required String revokedBy,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'revokeStandingPolicy',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'revokeStandingPolicy',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'policyId': policyId,
            'revokedBy': revokedBy,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i17.StandingPolicyView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i8.DecisionView> resolveBaselineApproval(
    _i1.TestSessionBuilder sessionBuilder, {
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'resolveBaselineApproval',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'resolveBaselineApproval',
          parameters: _i1.testObjectToJson({
            'decisionId': decisionId,
            'choice': choice,
            'decider': decider,
            'rationale': rationale,
            'signature': signature,
            'publicKey': publicKey,
            'algorithm': algorithm,
            'signedAt': signedAt,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i8.DecisionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i8.DecisionView> baselineApproval(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
    required String baselineId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'baselineApproval',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'baselineApproval',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'baselineId': baselineId,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i8.DecisionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i18.ClarificationView> answerClarification(
    _i1.TestSessionBuilder sessionBuilder, {
    required String clarificationId,
    required String answer,
    required String answeredBy,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'answerClarification',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'answerClarification',
          parameters: _i1.testObjectToJson({
            'clarificationId': clarificationId,
            'answer': answer,
            'answeredBy': answeredBy,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i18.ClarificationView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i14.ProductDetailView> createProduct(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
    required String name,
    String? description,
    String? manifestJson,
    String? manifestVersion,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'createProduct',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'createProduct',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'name': name,
            'description': description,
            'manifestJson': manifestJson,
            'manifestVersion': manifestVersion,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i14.ProductDetailView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> addRepositoryReference(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
    required String repositoryId,
    required String uri,
    required String kind,
    required String provider,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'addRepositoryReference',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'addRepositoryReference',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'repositoryId': repositoryId,
            'uri': uri,
            'kind': kind,
            'provider': provider,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i14.ProductDetailView> verifyBaseline(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
    required String baselineId,
    required String verifiedBy,
    required String kind,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'verifyBaseline',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'verifyBaseline',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'baselineId': baselineId,
            'verifiedBy': verifiedBy,
            'kind': kind,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i14.ProductDetailView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i14.ProductDetailView> addHumanBaselineClaim(
    _i1.TestSessionBuilder sessionBuilder, {
    required String productId,
    required String baselineId,
    required String section,
    required String claim,
    required String author,
    List<String>? evidenceRefs,
    String? maturity,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'productRegistryEndpoints',
            method: 'addHumanBaselineClaim',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'productRegistryEndpoints',
          methodName: 'addHumanBaselineClaim',
          parameters: _i1.testObjectToJson({
            'productId': productId,
            'baselineId': baselineId,
            'section': section,
            'claim': claim,
            'author': author,
            'evidenceRefs': evidenceRefs,
            'maturity': maturity,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i14.ProductDetailView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }
}

class _ProviderHealthEndpoints {
  _ProviderHealthEndpoints(
    this._endpointDispatch,
    this._serializationManager,
  );

  final _i2.EndpointDispatch _endpointDispatch;

  final _i2.SerializationManager _serializationManager;

  _i3.Future<Map<String, dynamic>> getProviderHealth(
    _i1.TestSessionBuilder sessionBuilder,
  ) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'providerHealthEndpoints',
            method: 'getProviderHealth',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'providerHealthEndpoints',
          methodName: 'getProviderHealth',
          parameters: _i1.testObjectToJson({}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> listModelPolicies(
    _i1.TestSessionBuilder sessionBuilder,
  ) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'providerHealthEndpoints',
            method: 'listModelPolicies',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'providerHealthEndpoints',
          methodName: 'listModelPolicies',
          parameters: _i1.testObjectToJson({}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> updateModelPolicy(
    _i1.TestSessionBuilder sessionBuilder, {
    required String role,
    required String chainJson,
    required int version,
    required String updatedByDecisionId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'providerHealthEndpoints',
            method: 'updateModelPolicy',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'providerHealthEndpoints',
          methodName: 'updateModelPolicy',
          parameters: _i1.testObjectToJson({
            'role': role,
            'chainJson': chainJson,
            'version': version,
            'updatedByDecisionId': updatedByDecisionId,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> listModelExecutions(
    _i1.TestSessionBuilder sessionBuilder, {
    String? workItemId,
    String? provider,
    String? modelId,
    DateTime? from,
    DateTime? to,
    required int limit,
    required int offset,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'providerHealthEndpoints',
            method: 'listModelExecutions',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'providerHealthEndpoints',
          methodName: 'listModelExecutions',
          parameters: _i1.testObjectToJson({
            'workItemId': workItemId,
            'provider': provider,
            'modelId': modelId,
            'from': from,
            'to': to,
            'limit': limit,
            'offset': offset,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> getModelStats(
    _i1.TestSessionBuilder sessionBuilder, {
    DateTime? from,
    DateTime? to,
    String? groupBy,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'providerHealthEndpoints',
            method: 'getModelStats',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'providerHealthEndpoints',
          methodName: 'getModelStats',
          parameters: _i1.testObjectToJson({
            'from': from,
            'to': to,
            'groupBy': groupBy,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }
}

class _SchedulerEndpoints {
  _SchedulerEndpoints(
    this._endpointDispatch,
    this._serializationManager,
  );

  final _i2.EndpointDispatch _endpointDispatch;

  final _i2.SerializationManager _serializationManager;

  _i3.Future<Map<String, dynamic>> listJobs(
    _i1.TestSessionBuilder sessionBuilder, {
    String? workItemId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'schedulerEndpoints',
            method: 'listJobs',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'schedulerEndpoints',
          methodName: 'listJobs',
          parameters: _i1.testObjectToJson({'workItemId': workItemId}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> inspect(
    _i1.TestSessionBuilder sessionBuilder, {
    required String jobId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'schedulerEndpoints',
            method: 'inspect',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'schedulerEndpoints',
          methodName: 'inspect',
          parameters: _i1.testObjectToJson({'jobId': jobId}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }
}

class _WorkerEndpoints {
  _WorkerEndpoints(
    this._endpointDispatch,
    this._serializationManager,
  );

  final _i2.EndpointDispatch _endpointDispatch;

  final _i2.SerializationManager _serializationManager;

  _i3.Future<Map<String, dynamic>> listWorkers(
    _i1.TestSessionBuilder sessionBuilder,
  ) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'workerEndpoints',
            method: 'listWorkers',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'workerEndpoints',
          methodName: 'listWorkers',
          parameters: _i1.testObjectToJson({}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> listExecutions(
    _i1.TestSessionBuilder sessionBuilder, {
    String? workItemId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'workerEndpoints',
            method: 'listExecutions',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'workerEndpoints',
          methodName: 'listExecutions',
          parameters: _i1.testObjectToJson({'workItemId': workItemId}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<Map<String, dynamic>> inspect(
    _i1.TestSessionBuilder sessionBuilder, {
    required String workerExecutionId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'workerEndpoints',
            method: 'inspect',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'workerEndpoints',
          methodName: 'inspect',
          parameters: _i1.testObjectToJson({
            'workerExecutionId': workerExecutionId,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<Map<String, dynamic>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }
}

class _WorkflowEndpoints {
  _WorkflowEndpoints(
    this._endpointDispatch,
    this._serializationManager,
  );

  final _i2.EndpointDispatch _endpointDispatch;

  final _i2.SerializationManager _serializationManager;

  _i3.Future<List<_i19.JobSummaryView>> jobsForWorkItem(
    _i1.TestSessionBuilder sessionBuilder, {
    required String workItemId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'workflowEndpoints',
            method: 'jobsForWorkItem',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'workflowEndpoints',
          methodName: 'jobsForWorkItem',
          parameters: _i1.testObjectToJson({'workItemId': workItemId}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<List<_i19.JobSummaryView>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i20.WorkItemDetailView> inspect(
    _i1.TestSessionBuilder sessionBuilder, {
    required String workItemId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'workflowEndpoints',
            method: 'inspect',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'workflowEndpoints',
          methodName: 'inspect',
          parameters: _i1.testObjectToJson({'workItemId': workItemId}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i20.WorkItemDetailView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<List<_i8.DecisionView>> listDecisions(
    _i1.TestSessionBuilder sessionBuilder, {
    required String workItemId,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'workflowEndpoints',
            method: 'listDecisions',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'workflowEndpoints',
          methodName: 'listDecisions',
          parameters: _i1.testObjectToJson({'workItemId': workItemId}),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<List<_i8.DecisionView>>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }

  _i3.Future<_i21.ResolveDecisionView> resolveDecision(
    _i1.TestSessionBuilder sessionBuilder, {
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String algorithm,
    required String publicKey,
    required String signature,
    required DateTime signedAt,
  }) async {
    return _i1.callAwaitableFunctionAndHandleExceptions(() async {
      var _localUniqueSession =
          (sessionBuilder as _i1.InternalTestSessionBuilder).internalBuild(
            endpoint: 'workflowEndpoints',
            method: 'resolveDecision',
          );
      try {
        var _localCallContext = await _endpointDispatch.getMethodCallContext(
          createSessionCallback: (_) => _localUniqueSession,
          endpointPath: 'workflowEndpoints',
          methodName: 'resolveDecision',
          parameters: _i1.testObjectToJson({
            'decisionId': decisionId,
            'choice': choice,
            'decider': decider,
            'rationale': rationale,
            'algorithm': algorithm,
            'publicKey': publicKey,
            'signature': signature,
            'signedAt': signedAt,
          }),
          serializationManager: _serializationManager,
        );
        var _localReturnValue =
            await (_localCallContext.method.call(
                  _localUniqueSession,
                  _localCallContext.arguments,
                )
                as _i3.Future<_i21.ResolveDecisionView>);
        return _localReturnValue;
      } finally {
        await _localUniqueSession.close();
      }
    });
  }
}
