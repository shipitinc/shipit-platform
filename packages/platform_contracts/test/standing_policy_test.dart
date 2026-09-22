import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

final _authorised = DateTime.utc(2026, 3, 1, 9);

StandingPolicy _policy({
  List<PolicyAction> actions = const [PolicyAction.push, PolicyAction.merge],
  String productId = 'shipit',
}) => StandingPolicy(
  policyId: 'pol-1',
  productId: productId,
  actions: actions,
  authorisingDecisionId: 'gd-p001',
  authorisedBy: 'operator',
  rationale: 'Approved 31 of 31 unchanged; production still gated.',
  authorisedAt: _authorised,
);

void main() {
  group('non-delegable actions are unrepresentable', () {
    test('PolicyAction cannot express promotion, approval or offboard', () {
      final wires = PolicyAction.values.map((a) => a.wire).toSet();
      expect(wires, {'push', 'merge'});
      for (final forbidden in [
        'production_promotion',
        'deployment_approval',
        'baseline_approval',
        'offboard',
      ]) {
        expect(
          () => PolicyAction.fromWire(forbidden),
          throwsFormatException,
          reason: '$forbidden must not be delegable to a standing policy',
        );
      }
    });

    test('the schema pins the same closed set', () {
      final schema = jsonDecode(
        File('../../schemas/standing_policy.schema.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final actions =
          (schema['properties'] as Map)['actions'] as Map<String, dynamic>;
      expect((actions['items'] as Map)['enum'], ['push', 'merge']);
      expect(actions['minItems'], 1);
    });
  });

  group('scope is bounded', () {
    test('a policy never covers another product', () {
      final p = _policy();
      expect(
        p.covers(
          productId: 'other',
          action: PolicyAction.push,
          at: _authorised.add(const Duration(hours: 1)),
        ),
        isFalse,
      );
    });

    test('a policy only covers the actions it names', () {
      final p = _policy(actions: const [PolicyAction.push]);
      final at = _authorised.add(const Duration(hours: 1));
      expect(p.authorises(PolicyAction.push, at: at), isTrue);
      expect(p.authorises(PolicyAction.merge, at: at), isFalse);
    });
  });

  group('policies never apply retroactively', () {
    test('an action before authorisation is not covered', () {
      final p = _policy();
      expect(
        p.authorises(
          PolicyAction.push,
          at: _authorised.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
        reason: 'an earlier action must not be re-attributed to this policy',
      );
    });

    test('an action exactly at authorisation time is covered', () {
      expect(_policy().authorises(PolicyAction.push, at: _authorised), isTrue);
    });
  });

  group('revocation', () {
    test('is itself attributable and recorded', () {
      final revoked = _policy().revoke(
        at: _authorised.add(const Duration(days: 2)),
        by: 'operator',
        reason: PolicyRevocationReason.revokedByHuman,
        decisionId: 'gd-p002',
      );
      expect(revoked.isRevoked, isTrue);
      expect(revoked.revokedBy, 'operator');
      expect(revoked.revocationDecisionId, 'gd-p002');
      expect(revoked.version, 2);
      // The original authorisation is preserved, not overwritten.
      expect(revoked.authorisingDecisionId, 'gd-p001');
      expect(revoked.rationale, contains('31 of 31'));
    });

    test('stops covering actions from the moment it is revoked', () {
      final revokedAt = _authorised.add(const Duration(days: 2));
      final p = _policy().revoke(
        at: revokedAt,
        by: 'operator',
        reason: PolicyRevocationReason.revokedByHuman,
      );
      expect(
        p.authorises(
          PolicyAction.push,
          at: revokedAt.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
        reason: 'actions before revocation stay legitimately authorised',
      );
      expect(p.authorises(PolicyAction.push, at: revokedAt), isFalse);
      expect(
        p.authorises(
          PolicyAction.push,
          at: revokedAt.add(const Duration(days: 1)),
        ),
        isFalse,
      );
    });

    test('archiving the subject is a distinct, recordable reason', () {
      final p = _policy().revoke(
        at: _authorised.add(const Duration(days: 1)),
        by: 'system',
        reason: PolicyRevocationReason.subjectArchived,
      );
      expect(p.revocationReason, PolicyRevocationReason.subjectArchived);
    });
  });

  group('wire contract', () {
    test('round-trips, with enums as wire strings', () {
      final p = _policy().revoke(
        at: _authorised.add(const Duration(days: 1)),
        by: 'operator',
        reason: PolicyRevocationReason.superseded,
        decisionId: 'gd-p003',
      );
      final json = p.toJson();
      expect(json['actions'], ['push', 'merge']);
      expect(json['revocationReason'], 'superseded');
      expect(StandingPolicy.fromJson(json), p);
    });

    test('every emitted key is declared in the schema', () {
      final schema = jsonDecode(
        File('../../schemas/standing_policy.schema.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final declared = (schema['properties'] as Map).keys.toSet();
      final emitted = _policy()
          .revoke(
            at: _authorised,
            by: 'operator',
            reason: PolicyRevocationReason.revokedByHuman,
            decisionId: 'gd-x',
          )
          .toJson()
          .keys
          .toSet();
      expect(emitted.difference(declared), isEmpty);
      expect(schema['additionalProperties'], isFalse);
    });

    test('unknown wire values are rejected, not defaulted', () {
      expect(() => PolicyAction.fromWire('deploy'), throwsFormatException);
      expect(
        () => PolicyRevocationReason.fromWire('expired'),
        throwsFormatException,
      );
    });

    test('authorisation carries who, why and which decision', () {
      final json = _policy().toJson();
      expect(json['authorisedBy'], isNotNull);
      expect(json['rationale'], isNotNull);
      expect(json['authorisingDecisionId'], isNotNull);
    });
  });
}
