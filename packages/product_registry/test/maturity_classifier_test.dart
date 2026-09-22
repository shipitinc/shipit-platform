import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:test/test.dart';

void main() {
  const classifier = MaturityClassifier();

  group('Maturity authority (keyword is not authority)', () {
    test('MATURITY_KEYWORD_NOT_AUTHORITY: planned keyword in prose is unknown', () {
      expect(
        classifier.classify(
          claim:
              'Observability is a future work item; the word planned appears '
              'in the slice report',
          evidencePaths: const ['docs/reports/misc.md'],
          provenance: Provenance.observed,
        ),
        BaselineMaturity.unknown,
      );
    });

    test('MATURITY_KEYWORD_NOT_AUTHORITY: deferred mention without authority is unknown', () {
      expect(
        classifier.classify(
          claim: 'The de-agg platform may someday be deferred',
          evidencePaths: const ['README.md'],
          provenance: Provenance.observed,
        ),
        BaselineMaturity.unknown,
      );
    });

    test('MATURITY_KEYWORD_NOT_AUTHORITY: future direction in prose is not planned', () {
      expect(
        classifier.classify(
          claim: 'We will argue about the future stack endlessly',
          evidencePaths: const ['docs/session-log.md'],
          provenance: Provenance.observed,
        ),
        BaselineMaturity.unknown,
      );
    });

    test('MATURITY_KEYWORD_NOT_AUTHORITY: implemented claim without current evidence', () {
      expect(
        classifier.classify(
          claim: 'The system is implemented according to the ADR',
          evidencePaths: const ['docs/adr/0010-github-actions-cicd.md'],
          provenance: Provenance.derived,
        ),
        BaselineMaturity.unknown,
      );
    });
  });

  group('Maturity evidence semantics', () {
    test('MATURITY_IMPLEMENTED_CONCRETE_EVIDENCE', () {
      expect(
        classifier.classify(
          claim: 'Serverpod configuration is present in the workspace pubspec',
          evidencePaths: const ['packages/deployment_protocol/pubspec.yaml'],
          provenance: Provenance.observed,
        ),
        BaselineMaturity.implemented,
      );
    });

    test('MATURITY_POLICY_AUTHORITY', () {
      expect(
        classifier.classify(
          claim:
              'AGENTS.md requires platform code to never import from apps; '
              'all agent adapters must live in agent_runtime',
          evidencePaths: const ['AGENTS.md'],
          provenance: Provenance.observed,
        ),
        BaselineMaturity.policy,
      );
    });

    test('MATURITY_PLANNED_ACCEPTED_ADR', () {
      expect(
        classifier.classify(
          claim:
              'OpenTofu will replace hand-rolled IaC; GitHub Actions will '
              'replace the CI engine',
          evidencePaths: const [
            'docs/adr/0009-opentofu-iac.md',
            'docs/adr/0010-github-actions-cicd.md',
          ],
          provenance: Provenance.derived,
        ),
        BaselineMaturity.planned,
      );
    });

    test('MATURITY_DEFERRED_EXPLICIT_AUTHORITY', () {
      expect(
        classifier.classify(
          claim:
              'Agent sandboxing is explicitly deferred to a later milestone '
              'by the ADR',
          evidencePaths: const ['docs/adr/0015-worker-execution-layer.md'],
          provenance: Provenance.derived,
        ),
        BaselineMaturity.deferred,
      );
    });

    test('MATURITY_NOT_IMPLEMENTED', () {
      expect(
        classifier.classify(
          claim:
              'GitHub Actions CI is not configured; no .github/workflows '
              'exists',
          evidencePaths: const ['.github/workflows'],
          provenance: Provenance.observed,
        ),
        BaselineMaturity.notImplemented,
      );
    });

    test('MATURITY_NOT_IMPLEMENTED_UNDERSCORE_WIRE_FORM', () {
      // Authority is the canonical wire value: BaselineMaturity.notImplemented
      // serializes as `not_implemented`. Pre-fix, the classifier matched the
      // `implemented` suffix and returned BaselineMaturity.implemented.
      final wire = BaselineMaturity.notImplemented.wire;
      expect(wire, 'not_implemented');

      expect(
        classifier.classify(
          claim: 'Artifact promotion to GCS: $wire',
          evidencePaths: const ['apps/server/lib/src/persistence'],
          provenance: Provenance.observed,
        ),
        BaselineMaturity.notImplemented,
      );

      expect(
        classifier.classify(
          claim: 'Deployment rollback is ${wire.toUpperCase()} in production',
          evidencePaths: const ['apps/server/lib/src/persistence'],
          provenance: Provenance.observed,
        ),
        BaselineMaturity.notImplemented,
      );
    });

    test('MATURITY_NOT_IMPLEMENTED_PROSE_FORM', () {
      // The nearby prose spelling must classify identically to the wire form.
      expect(
        classifier.classify(
          claim: 'Realtime log streaming is not implemented',
          evidencePaths: const ['apps/control_plane/lib/features'],
          provenance: Provenance.observed,
        ),
        BaselineMaturity.notImplemented,
      );
    });

    test('MATURITY_NOT_IMPLEMENTED_VARIANTS', () {
      // Separator/spelling variants of the same negation must not be read as
      // current state (`implemented` is matched as a token, not a substring).
      for (final negated in const [
        'Rollback is not-implemented',
        'Rollback is notImplemented',
        'Rollback is unimplemented',
      ]) {
        expect(
          classifier.classify(
            claim: negated,
            evidencePaths: const ['apps/server/lib/src/persistence'],
            provenance: Provenance.observed,
          ),
          BaselineMaturity.notImplemented,
          reason: 'negated form should be notImplemented: $negated',
        );
      }
    });

    test('MATURITY_NOT_IMPLEMENTED_BOUNDARY', () {
      // The negation match is token-bounded: words that merely contain a
      // negation substring are not absence claims.
      for (final notNegated in const [
        'The rollback path is reunimplemented',
        'The unimplementedness of rollback is unresolved',
      ]) {
        expect(
          classifier.classify(
            claim: notNegated,
            evidencePaths: const ['apps/server/lib/src/persistence'],
            provenance: Provenance.observed,
          ),
          isNot(BaselineMaturity.notImplemented),
          reason: 'should not be read as negated: $notNegated',
        );
      }
    });

    test('MATURITY_IMPLEMENTED_NOT_NEGATED', () {
      // The fix must not swallow a genuine present-tense claim.
      expect(
        classifier.classify(
          claim: 'The severity classifier is implemented in apps/server/lib',
          evidencePaths: const ['apps/server/lib'],
          provenance: Provenance.observed,
        ),
        BaselineMaturity.implemented,
      );
    });

    test('MATURITY_UNKNOWN_CONFLICT_UNDERSCORE', () {
      // A mixed present/absent claim stays a conflict — the fix must not turn
      // the conflict into a silent absence.
      expect(
        classifier.classify(
          claim: 'The capability is implemented but also NOT_IMPLEMENTED',
          evidencePaths: const ['apps/server/lib'],
          provenance: Provenance.derived,
        ),
        BaselineMaturity.unknown,
      );
    });

    test('MATURITY_UNKNOWN_CONFLICT', () {
      expect(
        classifier.classify(
          claim: 'The capability is implemented but also not implemented',
          evidencePaths: const ['apps/server/lib'],
          provenance: Provenance.derived,
        ),
        BaselineMaturity.unknown,
      );
    });

    test('MATURITY_ASSUMED_NOT_EVIDENCE', () {
      expect(
        classifier.classify(
          claim: 'Some feature is implemented',
          evidencePaths: const ['apps/server/lib'],
          provenance: Provenance.assumed,
          assumptionNote: 'assumed for illustration',
        ),
        BaselineMaturity.unknown,
      );
    });
  });
}