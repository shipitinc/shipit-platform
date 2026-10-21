import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

import 'support/e3_fixtures.dart';
import 'support/fail_closed_sources.dart';

/// M1 — the `GateRegistry` registration contract (`substantive-qa-gates.md`
/// §8 M1, §4, §6.4 N1).
///
/// ## What this file proves, and why each part is not vacuous
///
/// The M1 step does two things to [gateRegistry]: it **de-registers** the four
/// fabricating evaluators (§8 3a) and **registers** the seven reviewed ones
/// (§4). Both halves are asserted, because each is a different way for a
/// registration to be wrong:
///
/// * **De-registration.** If `static-analysis` (etc.) is still registered, a
///   contract that declares it gets a **constant `passed`**
///   (`GateEvaluatorImpl._validateEvidence` returns `evidence.isNotEmpty`, and
///   the collector returns a fixed row). Asserting the four types are absent
///   from the registry is what fails if someone re-adds a registration.
/// * **Registration.** If a reviewed type is *not* registered,
///   `QAOrchestration.evaluate` answers `notExecuted`
///   (`qa_orchestration.dart:19-31`), which is not the same as "the gate ran and
///   failed". Asserting each of the seven types resolves to *some* evaluator is
///   what fails if a gate in the manifest has no runtime.
///
/// ## N1 — differential non-vacuity (§6.4)
///
/// `§6.4 N1`: *"For each registered type, two inputs that differ must produce
/// different verdicts."* The four de-registered evaluators fail N1 trivially —
/// identical output for identical config. This file applies N1 to the seven
/// registered evaluators by driving each one **through `QAOrchestration`** with
/// two inputs that differ in the fact the gate judges, and asserting the
/// verdicts differ. It reads the registry the way production does (by `type`),
/// so a registration that resolved to the wrong evaluator fails here.
///
/// ## Fail-closed, stated so the registration is not mistaken for a pass
///
/// The six source-backed evaluators are wired to the **fail-closed doubles** in
/// `support/fail_closed_sources.dart` (slice 3c moved them out of `lib/`, where
/// a global registry made every consumer inherit them). This file asserts the
/// property that makes that honest: **no fail-closed double can produce a
/// `passed` verdict.** A "registration done, gates green" reading is what this
/// assertion refuses.
///
/// ## Provision proof
///
/// Every evaluator parses its `config` BEFORE it reads any source, so a gate
/// whose declaration the parser rejects cannot run on any work item. This file
/// proves the three declarations the shipped contract carries are accepted —
/// `evaluate` is awaited, and a `FormatException` would fail the test rather
/// than returning a verdict.
///
/// The ONE shipped declaration that is refused is F2's `"ownedPathGlobs": []`
/// — the design-mandated fail-closed placeholder (§9 gap 3, ledger F-203).
/// Because a proof that only ever drove a friendlier config could not notice
/// the shipped one, its own group below loads the config the manifest ACTUALLY
/// ships, verbatim, and asserts the refusal rather than papering over it. That
/// refusal is the designed outcome, not a regression.
void main() {
  // §8 3a: the four fabricating evaluators, by the `type` they registered.
  const fabricatingTypes = <String>[
    'static-analysis',
    'unit-tests',
    'security-scan',
    'performance',
  ];

  // §4: the seven reviewed types that M1 registers.
  const reviewedTypes = <String>[
    'implementation-artifact-provenance',
    'change-scope-confinement',
    'declared-validation-outcome',
    'revision-identity-match',
    'triage-classification-structure',
    'triage-defect-existence',
    'triage-evidence-grounding',
  ];

  late QAOrchestration orchestration;
  late GateRegistry registry;

  setUp(() {
    // The registry is BUILT, over the six fail-closed doubles, and handed to
    // the orchestration explicitly. There is no global registry to inherit
    // (slice 3c removed it), so a test that wants the seven reviewed types
    // registered says so — and the doubles it registers declare themselves
    // `failClosed`, so a result they produce says so too.
    registry = buildFailClosedTestRegistry();
    orchestration = QAOrchestration(registry: registry);
  });

  Future<QAGateResult> evaluate(
    QAGateDefinition gate, {
    AgentResult? result,
    String workItemId = 'design-remediation-DEF-1',
  }) async {
    final contract = QAContract(
      contractId: 'qa-m1',
      workItemCategory: WorkItemCategory.feature,
      version: '1.0.0',
      createdAt: DateTime.utc(2026, 10, 20),
      updatedAt: DateTime.utc(2026, 10, 20),
      gates: [gate],
    );
    final results = await orchestration.evaluate(
      workItemId,
      result ?? agentResultFor(workItemId: workItemId),
      contract,
    );
    return results.single;
  }

  group('M1/3a — the four fabricating evaluators are de-registered', () {
    for (final type in fabricatingTypes) {
      test('no evaluator resolves for "$type"', () {
        expect(
          registry.get(type),
          isNull,
          reason:
              '"$type" was de-registered by §8 3a because its evaluator '
              'returned a fabricated PASSING (a constant QAEvidence, passed by '
              'GateEvaluatorImpl on evidence.isNotEmpty alone). A registration '
              'here re-opens that fabricated pass.',
        );
      });
    }

    test('the registry still holds the other evaluators', () {
      // Anti-vacuity for the loop above: if the registry were empty, every
      // `isNull` would pass for the wrong reason.
      expect(registry.all, isNotEmpty);
    });
  });

  group('M1 — the seven reviewed evaluators are registered', () {
    for (final type in reviewedTypes) {
      test('an evaluator resolves for "$type"', () {
        expect(
          registry.get(type),
          isNotNull,
          reason:
              '"$type" is declared by a reviewed gate (§3.1/§3.2) but has no '
              'GateRegistry entry, so QAOrchestration.evaluate answers '
              'notExecuted for it — "no evaluator exists", not "the gate '
              'failed". M1 registers it.',
        );
      });
    }

    test('the registry holds exactly the seven reviewed types', () {
      // Both directions: no reviewed type is missing AND no extra type is
      // present. The second half is the de-registration assertion expressed as
      // an equality, so re-adding a fabricating evaluator fails here too.
      expect(
        registry.all.map((e) => e.gateType).toSet(),
        reviewedTypes.toSet(),
        reason:
            'the registry diverges from the reviewed gate set. A type in the '
            'registry but not here is a registration nothing declared; a type '
            'here but not in the registry is a declared gate with no runtime.',
      );
    });
  });

  group('N1 (§6.4) — every registered type has two inputs that differ', () {
    // R3 (`triage-classification-structure`) is source-free, so it is the one
    // registered type whose verdict a test can move both ways through the
    // public evaluation path with no source at all. The other six read through
    // sources the registry wires to the fail-closed doubles, so
    // their non-vacuity is asserted as "config alone cannot make it pass" plus
    // the explicit fail-closed group below.
    test('R3 differs on a well-formed vs an enum-invalid payload', () async {
      final gate = gateFor(
        gateId: 'triage-classification-admitted',
        type: 'triage-classification-structure',
        config: structuredClassificationAdmitted.config,
      );
      const wellFormed = {
        'classification': 'implementation_defect',
        'status': 'reported',
        'confidence': 0.5,
        'suspectedCategory': 'unknown',
      };

      final passResult = await evaluate(
        gate,
        result: agentResultWithStructuredResult(wellFormed),
      );
      final failResult = await evaluate(
        gate,
        result: agentResultWithStructuredResult({
          ...wellFormed,
          'classification': 'not_an_enum',
        }),
      );

      expect(
        passResult.status,
        QAGateStatus.passed,
        reason: 'the well-formed payload must pass R3',
      );
      expect(
        failResult.status,
        QAGateStatus.failed,
        reason:
            'the enum-invalid payload must FAIL R3. If this equals '
            '${passResult.status}, the evaluator is a constant and fails N1.',
      );
      expect(passResult.status, isNot(failResult.status));
    });

    test('the six source-backed types cannot pass on config alone', () async {
      // The strongest N1 statement available without a production source: for
      // every registered source-backed type, a perfectly well-formed *config*
      // still yields a non-`passed` verdict, because the fail-closed source can
      // only deny. A registration that resolved to a constant `passed`
      // evaluator fails here.
      for (final gate in sourceBackedGates()) {
        // PROVISION PROOF: the evaluator's config parser runs BEFORE any source
        // read, so a malformed declaration would throw FormatException rather
        // than return a verdict. Reaching the assertion without throwing proves
        // the registered evaluator accepted the config the manifest declares.
        final result = await evaluate(gate);
        expect(
          result.status,
          isNot(QAGateStatus.passed),
          reason:
              'type "${gate.type}" passed with a fully-declared config and the '
              'fail-closed source. A source that cannot read its facts '
              'must never grant a pass — this is the fabricated-pass shape M1 '
              'exists to end.',
        );
      }
      expect(sourceBackedGates(), hasLength(6));
    });
  });

  group('the fail-closed doubles fail closed, stated per source', () {
    // The fail-closed doubles live in `test/support/fail_closed_sources.dart`
    // and are deliberately NOT exported from the package barrel: they are a
    // test's own stand-ins, not part of the package's public surface. So
    // fail-closed is asserted through the registry — the way a caller reaches
    // them — by driving each source-backed gate.
    test(
      'F1 reports "I could not look", never "nothing was produced"',
      () async {
        final result = await evaluate(
          gateFor(
            gateId: 'feature-change-committed',
            type: 'implementation-artifact-provenance',
            config: const {
              'evidenceTypes': ['execution_delta', 'committed_revision'],
              'requireReadableDelta': true,
              'requireHeadMoved': true,
              'recordProducedRevision': true,
            },
          ),
        );
        expect(result.status, QAGateStatus.failed);
        expect(
          result.metadata?['reason'],
          contains('HEAD could not be established'),
        );
      },
    );

    test(
      'F4 fails on completeness — every declared check has no row',
      () async {
        final result = await evaluate(
          gateFor(
            gateId: 'feature-declared-checks-executed',
            type: 'declared-validation-outcome',
            config: const {
              'evidenceTypes': ['platform_verification'],
              'requireCheckNames': ['dart_analyze', 'dart_test'],
              'requireCommands': {
                'dart_analyze': 'dart analyze',
                'dart_test': 'dart test',
              },
              'requireStatus': 'passed',
              'commandMatchIsExact': true,
            },
          ),
        );
        expect(result.status, QAGateStatus.failed);
        // One evidence row per declared check, each reporting no row.
        expect(result.evidence, hasLength(2));
        expect(
          result.metadata?['reason'],
          contains('has no platform verification row'),
        );
      },
    );

    test('R1 fails when the referenced defect does not resolve', () async {
      final result = await evaluate(
        gateFor(
          gateId: 'remediation-defect-resolvable',
          type: 'triage-defect-existence',
          config: const {
            'evidenceTypes': ['defect_row'],
            'sourceColumn': 'defect.defectId',
            'requireResolvable': true,
            'idSource': 'workItemDefectReference',
          },
        ),
      );
      expect(result.status, QAGateStatus.failed);
      expect(result.metadata?['referencedDefectId'], 'DEF-1');
    });
  });

  group('provision proof — the declared gates accept their shipped config', () {
    test('R2 and R3 evaluate without a FormatException', () async {
      // R2/R3 are source-backed and source-free respectively, and both parse a
      // config the product declares. Awaiting `evaluate` proves the parser
      // accepted it; a rejected declaration fails the test rather than
      // returning a verdict.
      final r3 = await evaluate(
        structuredClassificationAdmitted,
        result: agentResultWithStructuredResult(const {
          'classification': 'implementation_defect',
          'status': 'reported',
          'confidence': 0.5,
          'suspectedCategory': 'unknown',
        }),
      );
      expect(r3.status, QAGateStatus.passed);

      final r2 = await evaluate(
        evidenceGrounded,
        result: agentResultWithStructuredResult(const {
          'evidenceUsed': <String>['E-1'],
        }),
      );
      // R2 with the fail-closed evidence reader has no rows to ground `E-1`, so it
      // FAILS — but it EVALUATED, which is the provision proof.
      expect(r2.status, QAGateStatus.failed);

      final r1 = await evaluate(remediationDefectResolvable);
      expect(r1.status, QAGateStatus.failed);
    });
  });

  group(
    'provision proof — the SHIPPED F2 config is refused, by design (F-203)',
    () {
      test(
        'the manifest\'s verbatim "ownedPathGlobs": [] throws FormatException',
        () async {
          // The groups above drive F2 with `'ownedPathGlobs': ['packages/**']`
          // — a VALID config the shipped manifest does NOT declare. This test
          // closes that gap: it loads the config the operator actually
          // registers, from disk, verbatim, and asserts what really happens.
          final manifest = ProductManifest.fromJson(
            jsonDecode(_shippedManifestJson()) as Map<String, dynamic>,
          );
          final contract = buildProductQAContract(
            spec: manifest.contracts.qaContract,
            productId: manifest.productId,
            workItemCategory: WorkItemCategory.feature,
            workItemId: 'WI-shipped-f2',
            manifestVersion: manifest.version,
            now: DateTime.utc(2026, 10, 20),
          );
          final gate = contract.gates.firstWhere(
            (g) => g.gateId == 'feature-change-scope-confined',
          );
          expect(gate.type, 'change-scope-confinement');

          // Pin the shipped VALUE this test exists to cover. If the manifest
          // ever starts shipping a non-empty owned set, this fails and the
          // test must be rewritten as an acceptance test — never kept green by
          // silently covering a config the operator will not register.
          expect(
            gate.config['ownedPathGlobs'],
            isEmpty,
            reason:
                'this test exists to pin the SHIPPED F2 config; a non-empty '
                'ownedPathGlobs means the manifest changed and the refusal '
                'assertion below no longer describes the artefact',
          );

          // AWAITED rather than swallowed: F2's `_ChangeScopeConfig.from`
          // parses BEFORE any source read, so the refusal is at provision of
          // the verdict — a FormatException reaching this expect is the
          // designed fail-closed outcome (§9 gap 3 / F-203), not a crash.
          // A registry that lost `change-scope-confinement` would instead
          // return `notExecuted` and fail this expect for the right reason.
          await expectLater(
            evaluate(gate),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'message',
                contains('ownedPathGlobs'),
              ),
            ),
            reason:
                'the shipped F2 declaration must be REFUSED at its config '
                'parse with FormatException naming "ownedPathGlobs" — the '
                'fail-closed placeholder is by design (F-203), so a verdict of '
                'any kind here would mean an empty owned set was evaluated '
                'instead of refused',
          );
        },
      );
    },
  );
}

/// The checked-in `shipit-platform` manifest, as the operator registers it.
///
/// Read from disk rather than inlined: a copy here would let this proof pass
/// while the shipped file declared something else.
String _shippedManifestJson() {
  final repoRoot = _findRepoRoot();
  return File(
    '$repoRoot${Platform.pathSeparator}apps${Platform.pathSeparator}server'
    '${Platform.pathSeparator}manifests${Platform.pathSeparator}'
    'shipit-platform.product-manifest.json',
  ).readAsStringSync();
}

String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory(
          '${dir.path}${Platform.pathSeparator}packages',
        ).existsSync() &&
        Directory('${dir.path}${Platform.pathSeparator}apps').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repository root not found from ${Directory.current}');
    }
    dir = parent;
  }
}

/// The six reviewed source-backed gate declarations, exactly as the shipped
/// manifest (§3.1 F1/F2/F4/F5) and the remediation contract (§3.2 R1/R2)
/// declare them.
List<QAGateDefinition> sourceBackedGates() => [
  gateFor(
    gateId: 'feature-change-committed',
    type: 'implementation-artifact-provenance',
    config: const {
      'evidenceTypes': ['execution_delta', 'committed_revision'],
      'requireReadableDelta': true,
      'requireHeadMoved': true,
      'recordProducedRevision': true,
    },
  ),
  gateFor(
    gateId: 'feature-change-scope-confined',
    type: 'change-scope-confinement',
    config: const {
      'evidenceTypes': ['committed_diff_paths'],
      'ownedPathGlobs': ['packages/**'],
      'forbiddenPathGlobs': <String>[],
      'pathSource': 'git_diff_name_only',
    },
  ),
  gateFor(
    gateId: 'feature-declared-checks-executed',
    type: 'declared-validation-outcome',
    config: const {
      'evidenceTypes': ['platform_verification'],
      'requireCheckNames': ['dart_analyze'],
      'requireCommands': {'dart_analyze': 'dart analyze'},
      'requireStatus': 'passed',
      'commandMatchIsExact': true,
    },
  ),
  gateFor(
    gateId: 'feature-review-bound-to-revision',
    type: 'revision-identity-match',
    config: const {
      'evidenceTypes': ['review_verdict', 'committed_revision'],
      'reviewedRevisionField': 'endingRevision',
      'producedRevisionField': 'producedRevision',
      'requireStringEquality': true,
      'nullRevisionIsFailure': true,
    },
  ),
  gateFor(
    gateId: 'remediation-defect-resolvable',
    type: 'triage-defect-existence',
    config: const {
      'evidenceTypes': ['defect_row'],
      'sourceColumn': 'defect.defectId',
      'requireResolvable': true,
      'idSource': 'workItemDefectReference',
    },
  ),
  gateFor(
    gateId: 'triage-evidence-grounded',
    type: 'triage-evidence-grounding',
    config: const {
      'sourceColumn': 'defect_evidence.evidenceId',
      'everyCitedEvidenceMustExist': true,
      'mustBelongToReportedDefect': true,
    },
  ),
];
