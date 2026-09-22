import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

RepositoryCredential _cred({
  CredentialStatus status = CredentialStatus.generated,
  HostKeyStatus hostKeyStatus = HostKeyStatus.unknown,
  DateTime? lastVerifiedAt,
  String? lastVerifiedBy,
  DateTime? hostConfirmedAt,
  String? hostConfirmedBy,
}) => RepositoryCredential(
  credentialId: 'cred-1',
  productId: 'shipit',
  repositoryId: 'repo-1',
  referenceName: 'GIT_PRODUCT_SHIPIT_SSH',
  publicKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO8vK2mN shipit+repo-1',
  fingerprint: 'SHA256:0Hq7xK2mN8vR4tL9wQ3sB6y',
  status: status,
  createdAt: DateTime.utc(2026, 1, 1),
  lastVerifiedAt: lastVerifiedAt,
  lastVerifiedBy: lastVerifiedBy,
  hostKeyStatus: hostKeyStatus,
  host: 'github.com',
  hostConfirmedAt: hostConfirmedAt,
  hostConfirmedBy: hostConfirmedBy,
);

void main() {
  group('no key material is representable', () {
    test('the serialised form carries only the public half', () {
      final json = _cred().toJson();
      // Nothing resembling a private key may appear in the durable record.
      final blob = jsonEncode(json).toLowerCase();
      expect(blob, isNot(contains('private')));
      expect(blob, isNot(contains('begin openssh')));
      expect(json.keys, isNot(contains('privateKey')));
      expect(json['publicKey'], startsWith('ssh-ed25519 '));
      expect(json['referenceName'], 'GIT_PRODUCT_SHIPIT_SSH');
    });

    test('the schema forbids any unlisted property', () {
      final schema = jsonDecode(
        File('../../schemas/repository_credential.schema.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(schema['additionalProperties'], isFalse);
      expect(
        (schema['properties'] as Map).keys,
        isNot(contains('privateKey')),
      );
    });

    test('every serialised key is declared in the schema', () {
      final schema = jsonDecode(
        File('../../schemas/repository_credential.schema.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final declared = (schema['properties'] as Map).keys.toSet();
      final emitted = _cred(
        lastVerifiedAt: DateTime.utc(2026, 1, 2),
        lastVerifiedBy: 'worker-7',
        hostConfirmedAt: DateTime.utc(2026, 1, 2),
        hostConfirmedBy: 'operator',
      ).toJson().keys.toSet();
      expect(emitted.difference(declared), isEmpty);
    });
  });

  group('access is proven, not assumed', () {
    test('a freshly generated credential cannot reach anything', () {
      final c = _cred();
      expect(c.status, CredentialStatus.generated);
      expect(c.canReachRepository, isFalse);
      expect(c.lastVerifiedAt, isNull);
    });

    test('a verified credential on an unknown host still cannot connect', () {
      final c = _cred(
        status: CredentialStatus.verified,
        lastVerifiedAt: DateTime.utc(2026, 1, 2),
        lastVerifiedBy: 'operator',
      );
      expect(c.status.isUsable, isTrue);
      expect(c.hostKeyStatus.permitsConnection, isFalse);
      expect(
        c.canReachRepository,
        isFalse,
        reason: 'host trust and credential validity are both required',
      );
    });

    test('a confirmed host with an unverified key cannot connect', () {
      final c = _cred(
        hostKeyStatus: HostKeyStatus.confirmed,
        hostConfirmedAt: DateTime.utc(2026, 1, 2),
        hostConfirmedBy: 'operator',
      );
      expect(c.isHostConfirmed, isTrue);
      expect(c.canReachRepository, isFalse);
    });

    test('both halves proven means it can reach the repository', () {
      final c = _cred(
        status: CredentialStatus.verified,
        lastVerifiedAt: DateTime.utc(2026, 1, 2),
        lastVerifiedBy: 'operator',
        hostKeyStatus: HostKeyStatus.confirmed,
        hostConfirmedAt: DateTime.utc(2026, 1, 2),
        hostConfirmedBy: 'operator',
      );
      expect(c.canReachRepository, isTrue);
    });

    test('a changed host key fails closed', () {
      final c = _cred(
        status: CredentialStatus.verified,
        lastVerifiedAt: DateTime.utc(2026, 1, 2),
        hostKeyStatus: HostKeyStatus.changed,
      );
      expect(c.hostKeyStatus.permitsConnection, isFalse);
      expect(c.canReachRepository, isFalse);
    });

    test('host confirmation requires an attributable human', () {
      final noWho = _cred(
        hostKeyStatus: HostKeyStatus.confirmed,
        hostConfirmedAt: DateTime.utc(2026, 1, 2),
      );
      expect(noWho.isHostConfirmed, isFalse);
    });

    test('a revoked credential is not usable but is still readable', () {
      final c = _cred(status: CredentialStatus.revoked);
      expect(c.status.isUsable, isFalse);
      expect(c.canReachRepository, isFalse);
      expect(c.toJson()['status'], 'revoked');
    });
  });

  group('wire contract', () {
    test('enums serialise as wire strings, never as .name', () {
      final json = _cred(hostKeyStatus: HostKeyStatus.confirmed).toJson();
      expect(json['status'], 'generated');
      expect(json['hostKeyStatus'], 'confirmed');
    });

    test('round-trips through JSON', () {
      final original = _cred(
        status: CredentialStatus.verified,
        lastVerifiedAt: DateTime.utc(2026, 1, 2),
        lastVerifiedBy: 'worker-7',
        hostKeyStatus: HostKeyStatus.confirmed,
        hostConfirmedAt: DateTime.utc(2026, 1, 2),
        hostConfirmedBy: 'operator',
      );
      expect(RepositoryCredential.fromJson(original.toJson()), original);
    });

    test('unknown wire values are rejected, not silently defaulted', () {
      expect(() => CredentialStatus.fromWire('probably_fine'),
          throwsFormatException);
      expect(() => HostKeyStatus.fromWire('trusted'), throwsFormatException);
    });

    test('scope is one repository', () {
      expect(_cred().repositoryId, 'repo-1');
      expect(_cred().productId, 'shipit',
          reason: 'retained for ownership checks, not for scope');
    });
  });
}
