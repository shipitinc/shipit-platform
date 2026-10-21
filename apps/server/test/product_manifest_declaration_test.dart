import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

/// The `shipit-platform` QA-contract DECLARATION, held to what it must assert.
///
/// ## Why a file on disk needs a test at all
///
/// `ProductManifest.contracts.qaContract` has had exactly one production
/// construction site for its whole life and it wrote an EMPTY gate list, and
/// `registerProductWithManifest` then discarded the manifest whole. The type
/// was therefore reachable and useless at the same time: a product could carry
/// a `QAContractSpec` that constrained nothing, and nothing downstream could
/// tell that apart from a product that carried none.
///
/// A checked-in declaration reopens exactly that door. `gates: []` is not a
/// mistake a compiler or a reviewer reliably catches — it parses, it type-checks,
/// it is a valid `ProductManifest`, and it produces
/// `ProductQAContractSpecRefusal.declaresNoGates` at provisioning time, which
/// reads as "this product declared nothing" rather than as "the declaration was
/// emptied". So the empty case, the placeholder-gate case and the drift case are
/// each named here.
///
/// ## WHY THE TRIAGE CONTRACT IS THE ORACLE, AND NOT A COMMENT
///
/// The two `config` keys this gate is required to mirror are asserted against
/// `structuredClassificationAdmitted` — the live constant in
/// `qa_orchestration`, not a transcription of it. Those four field names are
/// exactly the four `TriageProcessor._parseTriageResult` reads and throws a
/// `FormatException` on when absent
/// (`apps/server/lib/src/triage/triage_processor.dart:200-214`). Asserting
/// equality against the constant makes "the declaration drifted away from the
/// document it is about" a test failure instead of a reviewer's diligence.
///
/// ## WHAT IS DELIBERATELY NOT ASSERTED
///
/// That the gate is EVALUATED by a production runtime. After M1 the type
/// `triage-classification-structure` DOES have a `GateRegistry` entry — that
/// is asserted below (`gateRegistry.get(derived.type)` is `isNotNull`) — so
/// `QAOrchestration.evaluate` would no longer answer `notExecuted` for it.
/// What remains unbuilt is the evaluator drain (slice 3c): the derived
/// contract's metadata carries `evaluatorRuntime == 'absent'` (asserted
/// below), so no production run drives this gate end to end, and a test
/// asserting the gate "passes" would still be asserting a runtime that does
/// not exist. What is asserted instead is registration plus the explicit
/// `absent` marker, which keeps "registered" from being read as "running".
void main() {
  final repoRoot = _findRepoRoot();
  final manifestPath = p.join(
    repoRoot,
    'apps/server/manifests/shipit-platform.product-manifest.json',
  );

  final manifestFile = File(manifestPath);
  final manifest = ProductManifest.fromJson(
    jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
  );
  final gates = manifest.contracts.qaContract.gates;
  final intake = gates.firstWhere(
    (g) => g.gateId == 'intake-structured-result-admitted',
  );

  group('the shipit-platform declaration names the product it is for', () {
    test('it is the manifest for shipit-platform, version 1.0.0', () {
      expect(manifest.productId, 'shipit-platform');
      expect(manifest.version, '1.0.0');
    });
  });

  group('it declares a real gate rather than an absence of one', () {
    test('the gate list is NOT empty, so it is not declaresNoGates', () {
      // The failure this guards is silent and misnamed: an empty list
      // provisions nothing and is reported as `declaresNoGates`, which sends an
      // operator to fix "the product's QA contract" when the product never had
      // one in the first place.
      expect(
        gates,
        isNotEmpty,
        reason:
            'contracts.qaContract.gates is empty, so this manifest is the '
            'ABSENCE of a declaration, not one. '
            'ProductQAContractProvisioner will refuse every work item filed '
            'under shipit-platform with ProductQAContractSpecRefusal.'
            'declaresNoGates, and the three items stranded in agentExecuting '
            'stay stranded with a reason that misdescribes the cause.',
      );
    });

    test('it declares exactly FIVE gates, and the intake gate is required', () {
      expect(gates, hasLength(5));
      final intake = gates.firstWhere(
        (g) => g.gateId == 'intake-structured-result-admitted',
      );
      expect(intake.required, isTrue);
      expect(intake.type, 'triage-classification-structure');
    });
  });

  group('the gate asserts something observable about the intake run', () {
    test('sourceColumn is the triage contract\'s, verbatim', () {
      expect(
        intake.config['sourceColumn'],
        structuredClassificationAdmitted.config['sourceColumn'],
      );
      expect(
        intake.config['sourceColumn'],
        'agent_result.structuredResultJson',
      );
    });

    test('requiredFields is the triage contract\'s, in order', () {
      expect(
        intake.config['requiredFields'],
        structuredClassificationAdmitted.config['requiredFields'],
      );
      expect(intake.config['requiredFields'], <String>[
        'classification',
        'status',
        'confidence',
        'suspectedCategory',
      ]);
    });

    test('the enums it names are the ones the parser actually resolves', () {
      // `TriageProcessor._parseTriageResult` calls `DefectClassification
      // .fromWire` and `DefectStatus.fromWire` on these two, so a gate naming
      // any other enums would be asserting a check that does not exist.
      expect(intake.config['classificationEnum'], 'DefectClassification');
      expect(intake.config['statusEnum'], 'DefectStatus');
      expect(
        structuredClassificationAdmitted.config['classificationEnum'],
        'DefectClassification',
      );
      expect(
        structuredClassificationAdmitted.config['statusEnum'],
        'DefectStatus',
      );
    });

    test("it declares the triage contract's evidence type", () {
      // `buildProductQAContract` reads `config['evidenceTypes']` into
      // `QAGateDefinition.evidenceTypes`
      // (`declaredGateEvidenceTypesConfigKey`), because `QAGateSpec` has no such
      // field while the derived `QAGateDefinition` does. Absent means `[]`,
      // which reads as "no evidence type is declared" — a real difference in
      // what the gate can be evaluated against once an evaluator exists.
      expect(intake.config['evidenceTypes'], <String>[
        'triage_structured_result',
      ]);
      expect(
        intake.config['evidenceTypes'],
        structuredClassificationAdmitted.evidenceTypes,
        reason:
            'the two gates read the same document, so the evidence they name '
            'must be the same evidence — otherwise the one evaluator this '
            'type exists to have would need to accept two of them',
      );
    });
  });

  group('the gate reuses the triage gate type, deliberately', () {
    test('one type, one evaluator — not two names for one assertion', () {
      // Both gates read the SAME document and require the SAME fields. A second
      // type name would need a second `GateRegistry` entry for one assertion,
      // and the slice-3 evaluator would have to be written twice.
      expect(
        intake.type,
        structuredClassificationAdmitted.type,
      );
      expect(intake.type, 'triage-classification-structure');
    });
  });

  group('the declaration survives the provisioning derivation', () {
    test('buildProductQAContract carries every declared gate through', () {
      // The manifest is not the end of the road: it is read by
      // `ProductQAContractProvisioner.provisionForWorkItem` and turned into the
      // `QAContract` a work item is actually governed by. Deriving it here
      // proves the declared gate is not dropped, renamed or flattened between
      // the file and the row `qaContractExists()` reads.
      final contract = buildProductQAContract(
        spec: manifest.contracts.qaContract,
        productId: manifest.productId,
        workItemCategory: WorkItemCategory.feature,
        workItemId: 'WI-probe',
        manifestVersion: manifest.version,
        now: DateTime.utc(2026, 10, 17),
      );

      expect(contract.gates, hasLength(5));
      final derived = contract.gates.firstWhere(
        (g) => g.gateId == 'intake-structured-result-admitted',
      );
      expect(derived.gateId, 'intake-structured-result-admitted');
      expect(derived.type, 'triage-classification-structure');
      expect(derived.required, isTrue);
      expect(
        derived.config['requiredFields'],
        intake.config['requiredFields'],
      );
      expect(
        derived.evidenceTypes,
        structuredClassificationAdmitted.evidenceTypes,
        reason:
            'buildProductQAContract reads evidenceTypes out of the declared '
            'config. An empty list here would mean the gate declares no '
            'evidence it can ever be evaluated against.',
      );
      // Stated, not implied: nothing evaluates this type yet.
      expect(contract.metadata?['evaluatorRuntime'], 'absent');
      // After M1, the reviewed evaluator is registered; the runtime drain
      // (slice 3c) remains absent, and evaluatorRuntime stays 'absent' per Ruling 1.
      expect(gateRegistry.get(derived.type), isNotNull);
    });
  });
}

String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory(p.join(dir.path, 'packages')).existsSync() &&
        Directory(p.join(dir.path, 'apps')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repository root not found from ${Directory.current}');
    }
    dir = parent;
  }
}
