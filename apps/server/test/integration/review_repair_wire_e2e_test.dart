import 'dart:convert';

import 'package:control_plane_client/control_plane_client.dart' as realclient;
import 'package:platform_contracts/platform_contracts.dart' show AgentRole;
import 'package:control_plane_server/src/generated/endpoints.dart';
import 'package:control_plane_server/src/generated/protocol.dart';
import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// The review repair is REACHABLE — proven through the REAL generated client,
/// over real HTTP, against real PostgreSQL.
///
/// ## WHY THIS FILE EXISTS, AND WHAT IT WOULD HAVE DONE BEFORE
///
/// `apps/server/test/review_repair_action_test.dart` drives
/// `WorkItemActionEndpoints.repairUnreviewedReview` by direct method call. That
/// suite is correct about the CONTRACT and says nothing whatever about whether
/// the action is ON THE WIRE — and the distinction is not theoretical. Before
/// this correction the method carried `@doNotGenerate` and returned a
/// hand-written `SerializableModel` declared in `lib/src/endpoints/`, so:
///
///   * `serverpod generate` emitted NO connector row for it, so the server had
///     no route and every call 404'd;
///   * `ReviewRepairResult` appeared ZERO times in `protocol.dart`, so even once
///     the connector row existed the `SerializationManager` could not decode the
///     return value in EITHER direction;
///   * the generated client emitted an import for a file it never wrote, so
///     `packages/control_plane_client` did not analyze at all.
///
/// Every one of those failures is invisible to `dart analyze` on the server and
/// invisible to an in-process method call. This suite is the check that would
/// have caught all three, and it does so by doing exactly what the operator UI
/// will do: call `client.workItemActionEndpoints.repairUnreviewedReview(...)`
/// and decode the answer.
///
/// ## WHY IT IS AN INTEGRATION TEST AND NOT A UNIT TEST
///
/// The failure being closed is a WIRING failure, and wiring only exists once a
/// socket is involved: the connector table, the client's `callServerEndpoint`,
/// the serialized envelope and the `SerializationManager` are four separate
/// things that have to agree. There is no in-process arrangement of them that
/// is worth the name, so this suite starts the real Serverpod in test mode on a
/// real database and speaks HTTP.
///
/// ## WHAT IT ASSERTS, AND WHY EACH ASSERTION IS NOT RESTATABLE
///
///  * The call ROUND-TRIPS AS A TYPED MODEL. [realclient.Client]'s method is
///    declared `Future<ReviewRepairResult>`, so a decode failure is a thrown
///    exception, not a null — the assertion is reached only if both directions
///    of the serialization table are populated.
///  * EVERY FIELD SURVIVES, including `detail` and `decisionId`. Those two are
///    the reason the return type is its own model rather than an existing one:
///    reshaping it onto `WorkItemActionResult` would have compiled, analyzed
///    and shipped, and silently discarded the refusal explanation that is the
///    whole value of a refusal, plus the id of the decision it concerned.
///  * THE SERVER'S GUARDRAIL STILL HOLDS OVER THE WIRE. A real reviewer's
///    verdict is refused with nothing written. A wire test that only exercised
///    the accepting path would pass against a method that had lost its
///    guardrail, so the refusal is asserted here rather than left to the unit
///    suite that never touches serialization.
///  * A PENDING NON-REVIEW DECISION IS REFUSED, over the wire, with a
///    byte-identical before/after snapshot. `decisionTypeNotReviewable` is a
///    value the wire contract never carried before 2026-10-15, and a new outcome
///    string is exactly the kind of thing that exists on the server and never
///    arrives at a client. Two decision types, because the defect was structural
///    across all eighteen non-review types.
void main() {
  final openSessions = <Session>[];
  Serverpod? pod;

  Future<PersistenceDatabase> newDb() async {
    final session = await Serverpod.instance.createSession(
      enableLogging: false,
    );
    openSessions.add(session);
    return PersistenceDatabase(session.db);
  }

  /// Raw SQL reads, as plain maps.
  ///
  /// Deliberately NOT read through the generated protocol models: this suite is
  /// about the wire, and a row read back through the same serialization table
  /// the assertion is checking would be able to agree with a broken one.
  Future<List<Map<String, dynamic>>> rows(
    PersistenceDatabase db,
    String sql,
    Map<String, String> parameters,
  ) async {
    final result = await db.query(
      sql,
      parameters: QueryParameters.named(parameters),
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  /// Targeted DELETEs, never a TRUNCATE — `test/integration` shares one database
  /// with files that run concurrently. Every marker is namespaced `rrw-` to
  /// this file, and it runs in `setUp` as well as `tearDown` because a run that
  /// aborted mid-test leaves rows that would violate a unique constraint.
  Future<void> purgeSuiteRows() async {
    final db = await newDb();
    const item = 'rrw-%';
    const statements = <String>[
      'DELETE FROM "human_decision"       WHERE "workItemId" LIKE \'$item\'',
      'DELETE FROM "work_item_transition" WHERE "workItemId" LIKE \'$item\'',
      'DELETE FROM "agent_result"         WHERE "workItemId" LIKE \'$item\'',
      'DELETE FROM "work_item"            WHERE "workItemId" LIKE \'$item\'',
    ];
    for (final statement in statements) {
      await db.query(statement);
    }
  }

  /// A work item parked at `waiting_for_human_decision` behind an
  /// `engineering_review` decision that CLAIMS a verdict.
  ///
  /// [triageAttempt] seeds `metadata.triageAttempt`, so the discriminator the
  /// repair advances from is a real recorded value rather than an assumption.
  Future<void> seedParkedReview(
    String workItemId,
    String decisionId, {
    int triageAttempt = 3,
    String claimedVerdict = 'changes_required',
    String decisionType = 'engineering_review',
  }) async {
    final db = await newDb();
    final ts = DateTime.now().toUtc().toIso8601String();
    // Every value is BOUND, never interpolated. These rows carry JSON documents
    // whose braces and quotes are SQL syntax, and a fixture that inlines them
    // fails on the quoting rather than on the behaviour under test.
    await db.query(
      '''
      INSERT INTO work_item ("workItemId", "productId", "category", "title",
        "state", "blockingHumanDecisionId", "metadataJson",
        "createdAt", "updatedAt", "version")
      VALUES (@workItemId, 'p', 'feature', 'Fabricated review',
        'waiting_for_human_decision', @decisionId, @itemMetadata,
        @ts, @ts, 1)
    ''',
      parameters: QueryParameters.named({
        'workItemId': workItemId,
        'decisionId': decisionId,
        'itemMetadata': jsonEncode({'triageAttempt': triageAttempt}),
        'ts': ts,
      }),
    );
    // The decision names a reviewer execution and CLAIMS a verdict. The claim
    // is the bug: whether a reviewer really produced it is re-derived from
    // `agent_result`, never read off here.
    //
    // `decisionType` is BOUND, never interpolated, and defaults to
    // `engineering_review`. It exists so a NON-review decision can be seeded as
    // the row it really is — pending, blocking, claiming no reviewer verdict —
    // rather than as an engineering review with its type relabelled. The two
    // differ in whether `reviewExecutionId` and `reviewVerdict` are present at
    // all, which is precisely the distinction under test.
    final isReview = decisionType == 'engineering_review';
    await db.query(
      '''
      INSERT INTO human_decision ("decisionId", "workItemId", "decisionType",
        "status", "question", "recommendation", "blocking", "requestedAt",
        "updatedAt", "metadataJson")
      VALUES (@decisionId, @workItemId, @decisionType, 'pending',
        'Approve the implementation?', 'Approve', true, @ts, @ts,
        @decisionMetadata)
    ''',
      parameters: QueryParameters.named({
        'decisionId': decisionId,
        'workItemId': workItemId,
        'decisionType': decisionType,
        'decisionMetadata': jsonEncode({
          if (isReview) 'reviewExecutionId': '$workItemId-exec',
          if (isReview && claimedVerdict.isNotEmpty)
            'reviewVerdict': claimedVerdict,
        }),
        'ts': ts,
      }),
    );
  }

  /// The reviewer's OWN durable result, carrying a real machine-readable
  /// verdict. This is what a real review looks like, and it is the class the
  /// repair must never discard.
  Future<void> seedRealVerdict(
    String workItemId, {
    String verdict = 'changes_required',
  }) async {
    final db = await newDb();
    final ts = DateTime.now().toUtc().toIso8601String();
    // `diagnosticsJson` is a FULL `AgentDiagnostics` document, not an empty
    // object: `exitCode`, `durationMs` and `toolCalls` are non-nullable, so a
    // `'{}'` here makes `readResult` THROW and the repair reports the review as
    // UNREADABLE — a different refusal, reached for a fixture's reasons rather
    // than the code's. This is the same quiet-diagnostics shape
    // `review_repair_action_test.dart` builds.
    await db.query(
      '''
      INSERT INTO agent_result ("resultId", "sessionId", "workItemId", "status",
        "artifactsJson", "diagnosticsJson", "structuredResultJson",
        "executionId", "role", "completedAt")
      VALUES (@resultId, @sessionId, @workItemId, 'completed', '[]',
        @diagnostics, @structured, @executionId, @role, @ts)
    ''',
      parameters: QueryParameters.named({
        'resultId': 'result-$workItemId-exec',
        'sessionId': 'ses-$workItemId',
        'workItemId': workItemId,
        'diagnostics': jsonEncode({
          'exitCode': 0,
          'durationMs': 300000,
          'toolCalls': 0,
          'errors': <Object>[],
          'warnings': <Object>[],
        }),
        'structured': jsonEncode({'verdict': verdict}),
        'executionId': '$workItemId-exec',
        'role': AgentRole.engineeringReviewer.wire,
        'ts': ts,
      }),
    );
  }

  Future<Map<String, Object?>> snapshot(
    String workItemId, [
    String? decisionId,
  ]) async {
    final db = await newDb();
    final item = await rows(
      db,
      '''SELECT "state", "blockingHumanDecisionId", "metadataJson", "version"
         FROM work_item WHERE "workItemId" = @id''',
      {'id': workItemId},
    );
    final decision = await rows(
      db,
      '''SELECT "status", "choice", "metadataJson"
         FROM human_decision WHERE "decisionId" = @id''',
      {'id': decisionId ?? '$workItemId-dec'},
    );
    final history = await rows(
      db,
      '''SELECT "transitionId", "toState", "outcome", "idempotencyKey"
         FROM work_item_transition WHERE "workItemId" = @id''',
      {'id': workItemId},
    );
    return {
      'item': item.isEmpty ? null : item.first,
      'decision': decision.isEmpty ? null : decision.first,
      'history': history,
    };
  }

  late realclient.Client client;

  setUpAll(() async {
    pod = Serverpod(
      ['--mode', 'test', '--apply-migrations'],
      Protocol(),
      Endpoints(),
    );
    await pod!.start();
    client = realclient.Client('http://127.0.0.1:${pod!.server.port}/');
  });

  tearDownAll(() async {
    for (final session in List.of(openSessions)) {
      await session.close();
    }
    openSessions.clear();
    await pod?.shutdown(exitProcess: false);
  });

  group('the review repair is reachable on the wire', () {
    setUp(purgeSuiteRows);
    tearDown(purgeSuiteRows);

    test(
      'a fabricated decision is REPAIRED over real HTTP, and every field of '
      'the return value survives the round trip',
      () async {
        const workItemId = 'rrw-a';
        await seedParkedReview(workItemId, '$workItemId-dec');

        // THE CALL THE OPERATOR UI WILL MAKE. Before this correction the client
        // had no such method, so this file did not even compile.
        final result = await client.workItemActionEndpoints
            .repairUnreviewedReview(
              workItemId: workItemId,
              requestId: 'rrw-req-1',
              requestedBy: 'operator@example.com',
              reason: 'the reviewer timed out and produced nothing',
              decisionId: '$workItemId-dec',
            );

        expect(
          result.outcome,
          'accepted',
          reason:
              'a decision whose reviewer wrote no result is repairable, and the '
              'answer had to come back as a DECODED model rather than a thrown '
              'deserialization failure',
        );
        expect(
          result.decisionId,
          '$workItemId-dec',
          reason:
              'decisionId is the id of the decision this attempt concerned. A '
              'return type reshaped onto WorkItemActionResult has nowhere to '
              'carry it, which is one of the two reasons this is its own model.',
        );
        expect(
          result.detail,
          contains('retired as unreviewable'),
          reason:
              'detail is the diagnostic "why" and is the whole value of a '
              'refusal an operator has to act on. A reshaped return type drops '
              'it silently, and nothing else in the result carries it.',
        );
        expect(result.workItem.workItemId, workItemId);
        expect(
          result.workItem.state,
          'agent_completed',
          reason:
              'the repair returns the item to agent_completed, which IS '
              'engineeringReviewDefinition.entryStates, so the review is queued '
              'again rather than merely unblocked',
        );
        expect(result.workItem.blockingHumanDecisionId, isNull);

        // The write itself, read back from real PostgreSQL rather than from the
        // response the same call produced.
        final db = await newDb();
        final item = (await rows(
          db,
          '''SELECT "state", "blockingHumanDecisionId", "metadataJson"
             FROM work_item WHERE "workItemId" = @id''',
          {'id': workItemId},
        )).single;
        expect(item['state'], 'agent_completed');
        expect(item['blockingHumanDecisionId'], isNull);
        expect(
          jsonDecode(item['metadataJson']! as String)['triageAttempt'],
          4,
          reason:
              'the discriminator advances past the attempt the stranded review '
              'already consumed, or the re-queued review collides with the job '
              'that stranded the item',
        );

        final decision = (await rows(
          db,
          '''SELECT "status", "metadataJson" FROM human_decision
             WHERE "decisionId" = @id''',
          {'id': '$workItemId-dec'},
        )).single;
        expect(
          decision['status'],
          'cancelled',
          reason: 'RETIRED, not deleted — the row and its question survive',
        );
        final marker =
            jsonDecode(decision['metadataJson']! as String)
                as Map<String, dynamic>;
        expect(
          marker['reviewUnreviewable'],
          isTrue,
          reason: 'the marker is what says WHY a pending-looking row is dead',
        );
        expect(marker['reviewUnreviewedExecutionId'], '$workItemId-exec');

        final history = await rows(
          db,
          '''SELECT "toState", "idempotencyKey", "decisionId"
             FROM work_item_transition WHERE "workItemId" = @id''',
          {'id': workItemId},
        );
        expect(history, hasLength(1), reason: 'exactly one audit row');
        expect(history.first['idempotencyKey'], 'review-repair:rrw-req-1');
        expect(history.first['decisionId'], '$workItemId-dec');
      },
    );

    test(
      'a REAL reviewer verdict is still refused over the wire, and the refusal '
      'writes nothing',
      () async {
        const workItemId = 'rrw-b';
        await seedParkedReview(workItemId, '$workItemId-dec');
        await seedRealVerdict(workItemId, verdict: 'changes_required');
        final before = await snapshot(workItemId);

        final result = await client.workItemActionEndpoints
            .repairUnreviewedReview(
              workItemId: workItemId,
              requestId: 'rrw-req-2',
              requestedBy: 'operator@example.com',
              reason: 'I think nobody reviewed this',
              decisionId: '$workItemId-dec',
            );

        expect(
          result.outcome,
          'reviewerProducedVerdict',
          reason:
              'the guardrail is re-derived from the reviewer\'s own durable '
              'result over the wire, not read off the decision. A wire test that '
              'only exercised the accepting path would pass against a method '
              'that had quietly lost this.',
        );
        expect(
          result.detail,
          contains('changes_required'),
          reason:
              'and the refusal NAMES the verdict that really exists, so the '
              'operator can see the repair declined something real',
        );
        expect(
          result.workItem.state,
          'waiting_for_human_decision',
          reason: 'a refusal reports the item\'s TRUE current state',
        );
        expect(
          await snapshot(workItemId),
          before,
          reason: 'a refusal writes NOTHING',
        );
      },
    );

    test(
      'a PENDING NON-REVIEW decision is refused over the wire, and the '
      'refusal writes nothing',
      () async {
        // THE REGRESSION, ON THE WIRE.
        //
        // `readReviewVerdictProvenance` used to answer `noReviewerOutput` — the
        // only repairable class — for every decision type that is not
        // `engineering_review`, so all EIGHTEEN of them were "repairable" and a
        // single click retired a live human question and re-queued the work
        // behind it. `decisionTypeNotReviewable` is a NEW wire value, so it
        // needs the wire to prove: an outcome string that exists on the server
        // and never reaches a client is the exact class of failure this file
        // exists for.
        //
        // TWO types, because the defect is structural across the other eighteen.
        for (final wire in const [
          ('rrw-d-deployment', 'deployment_approval'),
          ('rrw-d-destructive', 'destructive_migration_approval'),
        ]) {
          final (workItemId, decisionType) = wire;
          final decisionId = '$workItemId-dec';
          await seedParkedReview(
            workItemId,
            decisionId,
            decisionType: decisionType,
          );
          final before = await snapshot(workItemId, decisionId);

          final result = await client.workItemActionEndpoints
              .repairUnreviewedReview(
                workItemId: workItemId,
                requestId: 'rrw-req-$decisionType',
                requestedBy: 'operator@example.com',
                reason: 'this looks parked and nobody reviewed it',
                decisionId: decisionId,
              );

          expect(
            result.outcome,
            'decisionTypeNotReviewable',
            reason:
                'a $decisionType decision is not an engineering review, so it '
                'claims no reviewer verdict and there is nothing to fabricate. '
                'It must be refused, and the value must survive the round trip.',
          );
          expect(
            result.detail,
            contains(decisionType),
            reason:
                'the refusal names what was checked. Saying "a reviewer really '
                'did return a verdict" here would refute a claim this decision '
                'never made.',
          );
          expect(
            result.decisionId,
            decisionId,
            reason: 'and it names the decision, so the receipt can be keyed',
          );
          expect(
            await snapshot(workItemId, decisionId),
            before,
            reason:
                'THE POINT OF THE SNAPSHOT: the refusal wrote nothing. The item '
                'is not re-queued, the pending question is not retired, and no '
                'audit row is appended.',
          );
        }
      },
    );

    test(
      'a replay of one operator intent over the wire is accepted and spends '
      'nothing twice',
      () async {
        const workItemId = 'rrw-c';
        await seedParkedReview(workItemId, '$workItemId-dec');

        Future<realclient.ReviewRepairResult> repair() =>
            client.workItemActionEndpoints.repairUnreviewedReview(
              workItemId: workItemId,
              requestId: 'rrw-req-3',
              requestedBy: 'operator@example.com',
              reason: 'the reviewer timed out and produced nothing',
            );

        final first = await repair();
        expect(first.outcome, 'accepted');
        final db = await newDb();
        final afterFirst = await rows(
          db,
          '''SELECT COUNT(*)::int AS n FROM work_item_transition
             WHERE "workItemId" = @id''',
          {'id': workItemId},
        );
        expect(afterFirst.single['n'], 1);

        // The same request id, as a lost response resent or a double-click
        // would send it.
        final second = await repair();
        expect(
          second.outcome,
          'accepted',
          reason:
              'a replay reports what that request DID rather than refusing '
              'itself as inapplicable after the item has moved on',
        );
        final afterSecond = await rows(
          db,
          '''SELECT COUNT(*)::int AS n FROM work_item_transition
             WHERE "workItemId" = @id''',
          {'id': workItemId},
        );
        expect(
          afterSecond.single['n'],
          1,
          reason:
              'a second discriminator bump would queue a SECOND review, which '
              'is the spend this idempotency key exists to prevent',
        );
      },
    );

    test(
      'a refusal for an item with nothing parked is reported, over the wire, '
      'in the same shape',
      () async {
        const workItemId = 'rrw-d';
        await seedParkedReview(workItemId, '$workItemId-dec');
        // The item moves on while the operator is looking at the screen.
        final db = await newDb();
        await db.query(
          '''UPDATE work_item SET "state" = 'agent_completed',
               "blockingHumanDecisionId" = NULL, "version" = 2
             WHERE "workItemId" = @id''',
          parameters: QueryParameters.named({'id': workItemId}),
        );

        final result = await client.workItemActionEndpoints
            .repairUnreviewedReview(
              workItemId: workItemId,
              requestId: 'rrw-req-4',
              requestedBy: 'operator@example.com',
              reason: 'stale screen',
            );

        expect(
          result.outcome,
          'notApplicable',
          reason:
              'this is the refusal a stale screen produces, and it is a NORMAL '
              'outcome with a defined meaning — which is why it has to decode '
              'as readily as the accepting one',
        );
        expect(result.workItem.state, 'agent_completed');
        expect(result.workItem.blockingHumanDecisionId, isNull);
      },
    );
  });
}
