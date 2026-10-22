import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// THE LANE PATH-OWNERSHIP DECLARATION'S PLUMBING.
///
/// ## WHAT THIS FILE MEASURES
///
/// The declaration travels through two durable records and is written by one
/// component and read by another. That makes the KEY a contract between two
/// packages, and a key spelled differently on the two ends produces a record
/// that reads as EMPTY — which is the fail-closed direction, so the defect
/// would not announce itself as a defect.
///
/// These tests pin the two ends: what the writer writes, and what the reader
/// reads back — including the shapes that must read as "declared nothing"
/// rather than as a narrower or wider grant.
void main() {
  group('the writer', () {
    test('records the globs under the shared key', () {
      final metadata = declaredOwnedPathsMetadata(const [
        'apps/server/**',
        'packages/qa_orchestration/**',
      ]);

      expect(metadata[declaredOwnedPathsMetadataKey], [
        'apps/server/**',
        'packages/qa_orchestration/**',
      ]);
    });

    test('writes the key even when the declaration is EMPTY', () {
      // "Dispatched and declared nothing" and "no capture was made" are
      // different records. Only one of them is a statement about the lane.
      final metadata = declaredOwnedPathsMetadata(const []);

      expect(metadata, contains(declaredOwnedPathsMetadataKey));
      expect(metadata[declaredOwnedPathsMetadataKey], isEmpty);
    });

    test('copies the list, so a later mutation cannot change the record', () {
      final globs = <String>['apps/server/**'];
      final metadata = declaredOwnedPathsMetadata(globs);

      globs.add('packages/qa_orchestration/**');

      expect(metadata[declaredOwnedPathsMetadataKey], ['apps/server/**']);
    });
  });

  group('the reader', () {
    test('reads back what the writer wrote', () {
      final metadata = declaredOwnedPathsMetadata(const ['apps/server/**']);

      expect(declaredOwnedPathsFromMetadata(metadata), ['apps/server/**']);
    });

    test('reads NO metadata as an empty declaration', () {
      expect(declaredOwnedPathsFromMetadata(null), isEmpty);
      expect(declaredOwnedPathsFromMetadata(const {}), isEmpty);
    });

    test('reads a MALFORMED declaration as an empty one', () {
      // Not a partial read. Narrowing a malformed grant to the entries that
      // happen to parse would be a grant read as a smaller grant — safe only
      // by accident — and widening it would be worse.
      expect(
        declaredOwnedPathsFromMetadata({
          declaredOwnedPathsMetadataKey: ['apps/server/**', 42],
        }),
        isEmpty,
      );
      expect(
        declaredOwnedPathsFromMetadata({
          declaredOwnedPathsMetadataKey: 'apps/server/**',
        }),
        isEmpty,
      );
      expect(
        declaredOwnedPathsFromMetadata({
          declaredOwnedPathsMetadataKey: ['apps/server/**', '   '],
        }),
        isEmpty,
      );
    });

    test('trims the globs it reads', () {
      expect(
        declaredOwnedPathsFromMetadata({
          declaredOwnedPathsMetadataKey: ['  apps/server/**  '],
        }),
        ['apps/server/**'],
      );
    });
  });

  group('the request carries the declaration', () {
    test('a request round-trips the declaration through JSON', () {
      final request = _request(const ['apps/server/**']);

      final decoded = WorkerExecutionRequest.fromJson(request.toJson());

      expect(decoded.declaredOwnedPaths, ['apps/server/**']);
    });

    test('a request with no declaration carries an EMPTY one', () {
      expect(_request(const []).declaredOwnedPaths, isEmpty);
    });

    test('copyWith replaces the declaration and keeps everything else', () {
      final request = _request(const ['apps/server/**']);

      final copy = request.copyWith(
        declaredOwnedPaths: const ['packages/qa_orchestration/**'],
      );

      expect(copy.declaredOwnedPaths, ['packages/qa_orchestration/**']);
      expect(copy.workItemId, request.workItemId);
      expect(copy.instruction, request.instruction);
      expect(copy.requiredCapabilities, request.requiredCapabilities);
      expect(copy.runtimeConfig, request.runtimeConfig);
    });

    test('copyWith keeps the declaration when it is not named', () {
      final request = _request(const ['apps/server/**']);

      expect(request.copyWith().declaredOwnedPaths, ['apps/server/**']);
    });
  });
}

WorkerExecutionRequest _request(List<String> declaredOwnedPaths) {
  return WorkerExecutionRequest(
    workerExecutionId: 'wx-1',
    workItemId: 'wi-1',
    repositoryPath: '/repo',
    startingRevision: 'abc123',
    requiredCapabilities: const {WorkerCapability.linux},
    role: AgentRole.implementer,
    instruction: 'implement the thing',
    timeoutSeconds: 60,
    runtimeTypeId: 'fake-runtime',
    runtimeConfig: const {'executable': 'opencode'},
    declaredOwnedPaths: declaredOwnedPaths,
  );
}
