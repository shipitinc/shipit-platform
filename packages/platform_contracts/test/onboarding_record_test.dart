import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// The record's ability to CARRY a pinned revision and a workspace.
///
/// These are properties of the type and of its JSON form, so they are asserted
/// as such. The store round-trip lives in `packages/product_registry` and the
/// database shape in `apps/server/test/product_registry_migration_test.dart`;
/// what is asserted here is the half that both of those depend on — that the
/// record can hold the answer, cannot hold a contradictory one, and does not
/// stop being readable when the answer is absent.
void main() {
  const sha = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4';
  const otherSha = 'f0e1d2c3b4a5968778695a4b3c2d1e0f9a8b7c6d';
  final created = DateTime.utc(2026, 10, 12, 21, 30, 45);

  WorkspaceDescriptor workspace({String startingRevision = sha}) =>
      WorkspaceDescriptor(
        workspaceId: 'ws-shipit-1',
        workerExecutionId: 'we-shipit-1',
        workerId: 'wk-local-1',
        repositoryPath: '/var/shipit/repos/shipit-platform',
        startingRevision: startingRevision,
        worktreePath: '/var/shipit/workspaces/shipit-platform-ws-shipit-1',
        createdAt: created,
      );

  OnboardingRecord record({
    String? pinnedRevision,
    WorkspaceDescriptor? workspaceOverride,
    String? completedBaselineId,
    bool completed = false,
  }) => OnboardingRecord(
    onboardingId: 'ob-shipit',
    productId: 'shipit',
    currentBaselineRevision: 1,
    pendingClarifications: 0,
    completed: completed,
    pinnedRevision: pinnedRevision,
    workspace: workspaceOverride,
    completedBaselineId: completedBaselineId,
    createdAt: created,
    updatedAt: created,
  );

  group('carrying the answer', () {
    test('the default record is unpinned and says so', () {
      final r = record();
      expect(r.pinnedRevision, isNull);
      expect(r.workspace, isNull);
      expect(r.completedBaselineId, isNull);
      // "No pin" must be readable as its own state, not inferred from a
      // missing field or a `currentBaselineRevision` of 0.
      expect(r.hasDurableWorkspace, isFalse);
      expect(r.hasLiveWorkspace, isFalse);
    });

    test('a pinned record with a live workspace answers both questions', () {
      final r = record(pinnedRevision: sha, workspaceOverride: workspace());
      expect(r.pinnedRevision, sha);
      expect(r.workspace!.worktreePath, contains('shipit-platform'));
      expect(r.hasLiveWorkspace, isTrue);
      expect(r.hasDurableWorkspace, isTrue);
      r.validate();
    });

    test('a CLEANED workspace is not a live workspace, and the pin survives', () {
      // The deletion case this whole lane exists for. Deleting the column
      // instead of recording the cleanup would leave no statement that a
      // workspace was ever created, and would make the record indistinguishable
      // from a product that was never pinned.
      final cleaned = workspace().markCleaned(
        created.add(const Duration(days: 1)),
      );
      final r = record(pinnedRevision: sha, workspaceOverride: cleaned);
      expect(r.hasLiveWorkspace, isFalse);
      expect(r.hasDurableWorkspace, isFalse);
      expect(r.pinnedRevision, sha, reason: 'the pin is not the workspace');
      expect(r.workspace!.isCleaned, isTrue);
      r.validate();
    });

    test('a pin with no workspace is not a durable answer', () {
      // Half the answer is not the answer. Reading `pinnedRevision` directly
      // would report a product as locatable when nothing was ever cloned.
      expect(record(pinnedRevision: sha).hasDurableWorkspace, isFalse);
    });

    test('a workspace with no pin is not a durable answer either', () {
      expect(
        record(workspaceOverride: workspace()).hasDurableWorkspace,
        isFalse,
      );
    });
  });

  group('completion carries evidence', () {
    test('completed alone is not evidence', () {
      final r = record(completed: true);
      expect(r.completed, isTrue);
      expect(
        r.hasCompletionEvidence,
        isFalse,
        reason: 'this is the bare-bool state the store contract permits',
      );
    });

    test('completed with its baseline and a revision IS evidence', () {
      final r = record(
        completed: true,
        completedBaselineId: 'bl-shipit-1',
        pinnedRevision: sha,
        workspaceOverride: workspace(),
      );
      expect(r.hasCompletionEvidence, isTrue);
    });

    test('a baseline id with no revision does not make it evidence', () {
      final r = OnboardingRecord(
        onboardingId: 'ob-shipit',
        productId: 'shipit',
        currentBaselineRevision: 0,
        completed: true,
        completedBaselineId: 'bl-shipit-1',
        createdAt: created,
        updatedAt: created,
      );
      expect(r.hasCompletionEvidence, isFalse);
    });
  });

  group('validation', () {
    test('accepts an absent pin', () {
      record().validate();
    });

    test('accepts a full 40-hex lowercase SHA', () {
      record(pinnedRevision: sha, workspaceOverride: workspace()).validate();
    });

    for (final bad in <String, String>{
      'an abbreviated SHA': '1111111',
      'HEAD': 'HEAD',
      'a branch name': 'feat/onboarding-workspace-durable',
      'uppercase hex': sha.toUpperCase(),
      '39 hex chars': sha.substring(1),
      '41 hex chars': '${sha}0',
      'whitespace padded': ' $sha ',
    }.entries) {
      test('rejects ${bad.key} as a pin', () {
        // `ws startingRevision` is pinned to the valid SHA here so the only
        // thing under test is the pin's own shape.
        expect(
          () => record(
            pinnedRevision: bad.value,
            workspaceOverride: workspace(),
          ).validate(),
          throwsA(isA<FormatException>()),
          reason: '"${bad.value}" must not be storable as a pinned revision',
        );
      });
    }

    test('rejects a workspace whose startingRevision is not a commit', () {
      expect(
        () => record(
          workspaceOverride: workspace(startingRevision: 'not-a-sha'),
        ).validate(),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a pin that contradicts its own workspace', () {
      // Each half is a well-formed SHA here, so a shape check on either alone
      // passes. Only the pair reveals that the record is answering two
      // different questions at once.
      expect(
        () => record(
          pinnedRevision: sha,
          workspaceOverride: workspace(startingRevision: otherSha),
        ).validate(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(sha),
          ),
        ),
      );
    });

    test('the thrown message names the pin AND the workspace start', () {
      try {
        record(
          pinnedRevision: sha,
          workspaceOverride: workspace(startingRevision: otherSha),
        ).validate();
        fail('validate() accepted a contradictory record');
      } on FormatException catch (e) {
        expect(e.message, contains(sha));
        expect(e.message, contains(otherSha));
      }
    });
  });

  group('JSON wire form', () {
    test('a fully populated record round-trips through JSON', () {
      final r = record(
        pinnedRevision: sha,
        workspaceOverride: workspace(),
        completedBaselineId: 'bl-shipit-1',
        completed: true,
      );
      expect(OnboardingRecord.fromJson(r.toJson()), r);
    });

    test('a populated workspace round-trips through its embedded JSON', () {
      final r = record(pinnedRevision: sha, workspaceOverride: workspace());
      final decoded = OnboardingRecord.fromJson(r.toJson());
      expect(decoded.workspace!.workspaceId, 'ws-shipit-1');
      expect(
        decoded.workspace!.repositoryPath,
        '/var/shipit/repos/shipit-platform',
      );
      expect(decoded.workspace!.detached, isTrue);
      expect(decoded.workspace!.branch, isNull);
      expect(decoded.workspace!.cleanedAt, isNull);
      expect(decoded.workspace, r.workspace);
    });

    test('a cleaned workspace round-trips its cleanup timestamp', () {
      final at = created.add(const Duration(days: 3));
      final r = record(
        pinnedRevision: sha,
        workspaceOverride: workspace().markCleaned(at),
      );
      final decoded = OnboardingRecord.fromJson(r.toJson());
      expect(decoded.workspace!.cleanedAt, at);
      expect(decoded.workspace!.isCleaned, isTrue);
      expect(decoded.hasLiveWorkspace, isFalse);
    });

    test('the fields are OMITTED when absent, not written as null', () {
      // `includeIfNull: false` is what makes a pre-migration row's JSON byte-
      // identical to what it always was. Emitting explicit nulls would make
      // every historical record's serialised form change for no information.
      final json = record().toJson();
      expect(json.containsKey('pinnedRevision'), isFalse);
      expect(json.containsKey('workspace'), isFalse);
      expect(json.containsKey('completedBaselineId'), isFalse);
    });

    test('a PRE-MIGRATION record still loads — absent keys, not nulls', () {
      // This is the exact document an existing row deserialises to: the eight
      // fields it was written with, and nothing else. Backward compatibility
      // is the reason the columns are nullable and omitted, and it is asserted
      // against the literal shape rather than against a record built from this
      // version's defaults.
      final legacy = <String, dynamic>{
        'onboardingId': 'ob-shipit-1',
        'productId': 'prod-shipit',
        'currentBaselineRevision': 1,
        'pendingClarifications': 1,
        'completed': false,
        'createdAt': '2026-09-16T12:00:00Z',
        'updatedAt': '2026-09-16T12:00:00Z',
        'version': 1,
      };
      final loaded = OnboardingRecord.fromJson(legacy);
      expect(loaded.onboardingId, 'ob-shipit-1');
      expect(loaded.currentBaselineRevision, 1);
      expect(loaded.pinnedRevision, isNull);
      expect(loaded.workspace, isNull);
      expect(loaded.completedBaselineId, isNull);
      expect(loaded.hasDurableWorkspace, isFalse);
      // And it re-serialises to the same eight fields.
      expect(loaded.toJson().keys.toSet(), legacy.keys.toSet());
      expect(loaded.toJson(), isNot(contains('pinnedRevision')));
    });

    test('an EXPLICIT null for the new keys also loads', () {
      // A different reader may write them as nulls rather than omitting them.
      // Both spellings of "unknown" must reach the same state.
      final loaded = OnboardingRecord.fromJson({
        'onboardingId': 'ob-shipit-1',
        'productId': 'prod-shipit',
        'currentBaselineRevision': 0,
        'pendingClarifications': 0,
        'completed': false,
        'pinnedRevision': null,
        'workspace': null,
        'completedBaselineId': null,
        'createdAt': '2026-09-16T12:00:00Z',
        'updatedAt': '2026-09-16T12:00:00Z',
        'version': 1,
      });
      expect(loaded.pinnedRevision, isNull);
      expect(loaded.workspace, isNull);
      expect(loaded.hasDurableWorkspace, isFalse);
    });

    test('the record is still Equatable over its new fields', () {
      final base = record(pinnedRevision: sha, workspaceOverride: workspace());
      expect(base, record(pinnedRevision: sha, workspaceOverride: workspace()));

      final otherPin = record(
        pinnedRevision: otherSha,
        workspaceOverride: workspace(startingRevision: otherSha),
      );
      expect(base, isNot(otherPin));

      final withBaseline = record(
        pinnedRevision: sha,
        workspaceOverride: workspace(),
        completedBaselineId: 'bl-shipit-1',
      );
      expect(base, isNot(withBaseline));

      // The workspace is a field of its own, so two records differing only in
      // it are different records — including on the `cleanedAt` transition,
      // which leaves every other field alone.
      final cleaned = record(
        pinnedRevision: sha,
        workspaceOverride: workspace().markCleaned(created),
      );
      expect(base, isNot(cleaned));
    });
  });

  group('copyWith', () {
    test('sets and carries the new fields', () {
      final r = record().copyWith(
        pinnedRevision: sha,
        workspace: workspace(),
        completedBaselineId: 'bl-shipit-1',
      );
      expect(r.pinnedRevision, sha);
      expect(r.workspace, isNotNull);
      expect(r.completedBaselineId, 'bl-shipit-1');
    });

    test('a null argument FALLS BACK, so a pin cannot be silently cleared', () {
      // Same convention as every other nullable field in this package's
      // `copyWith` (see `RepositoryCredential.copyWith`). Clearing a pin
      // means writing a fresh record, not passing a null that reads as
      // "no change" — a silent clear here would un-pin a product nobody
      // asked to un-pin.
      final pinned = record(
        pinnedRevision: sha,
        workspaceOverride: workspace(),
      );
      final unchanged = pinned.copyWith(pinnedRevision: null, workspace: null);
      expect(unchanged.pinnedRevision, sha);
      expect(unchanged.workspace, isNotNull);
    });
  });
}
