import 'dart:async';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// A scripted ACP server for triage turns. Emits the same `session/update`
/// notifications the real `opencode acp` does, so the session is exercised
/// without a live binary, network, or credentials.
class ScriptedAcpTransport implements AcpTransport {
  ScriptedAcpTransport({
    required this.updates,
    this.promptResult = const {'stopReason': 'end_turn'},
  });

  /// `session/update` update entries, delivered in order on `session/prompt`.
  final List<Map<String, dynamic>> updates;
  final Map<String, dynamic> promptResult;

  final _notifications = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  int promptRequests = 0;
  bool _open = true;

  @override
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<AcpInitializeResult> initialize() async {
    return const AcpInitializeResult(
      protocolVersion: 1,
      agentCapabilities: {
        'sessionCapabilities': {'resume': true},
      },
      agentInfo: {'name': 'OpenCode', 'version': 'test'},
      authMethods: [],
    );
  }

  @override
  Future<Map<String, dynamic>> request(
    int id,
    String method,
    Map<String, dynamic> params,
  ) async {
    switch (method) {
      case 'initialize':
        return {
          'protocolVersion': 1,
          'agentInfo': {'name': 'OpenCode', 'version': 'test'},
        };
      case 'session/new':
        return {'sessionId': 'ses_triage'};
      case 'setSessionConfigOption':
        return {};
      case 'session/prompt':
        promptRequests += 1;
        for (final update in updates) {
          _notifications.add({
            'method': 'session/update',
            'params': {
              'sessionId': 'ses_triage',
              'updates': [update],
            },
          });
        }
        return promptResult;
      default:
        throw AcpRequestException(-32601, 'method not found: $method');
    }
  }

  @override
  Future<void> close() async {
    _open = false;
    await _notifications.close();
  }
}

Map<String, dynamic> _chunk(String text) => {
  'type': 'agent_message_chunk',
  'message': {
    'messageId': 'm1',
    'content': {'type': 'text', 'text': text},
  },
};

Map<String, dynamic> _message(String text) => {
  'type': 'agent_message',
  'message': {
    'messageId': 'm2',
    'content': {
      'type': 'text',
      'parts': [
        {'type': 'text', 'text': text},
      ],
    },
  },
};

Future<AgentResult> _runTriageTurn(
  List<Map<String, dynamic>> updates, {
  Map<String, dynamic> promptResult = const {'stopReason': 'end_turn'},
}) async {
  final session = OpenCodeSession(
    executionId: 'exec-1',
    workItemId: 'defect-42',
    transportFactory: (_) async =>
        ScriptedAcpTransport(updates: updates, promptResult: promptResult),
  );
  await session.start(
    const AgentSessionConfig(
      executionId: 'exec-1',
      workItemId: 'defect-42',
      workingDirectory: '/tmp/ws',
    ),
  );
  await session.sendInstruction(
    const AgentInstruction(
      instructionId: 'instr-1',
      content: 'Perform AI triage of defect "crash on save" (42).',
    ),
  );
  final result = await session.getResult();
  await session.close();
  return result;
}

void main() {
  group('OpenCodeSession structured result', () {
    // The exact reads `TriageProcessor._parseTriageResult` performs against
    // `AgentResult.structuredResult`, in the parser's own order. The app-side
    // parser is not importable from this package, so its calls into the
    // contract enums are reproduced here; if any of these throw or come back
    // null, the parser would log `triage.parse.failed` and return null.
    TriageResultFields parseLikeTriageProcessor(
      Map<String, dynamic> structured,
    ) {
      final classificationStr = structured['classification'] as String?;
      expect(
        classificationStr,
        isNotNull,
        reason: 'parser requires classification',
      );
      final statusStr = structured['status'] as String?;
      expect(statusStr, isNotNull, reason: 'parser requires status');
      final confidence = (structured['confidence'] as num?)?.toDouble();
      expect(confidence, isNotNull, reason: 'parser requires confidence');
      final suspectedCategory = structured['suspectedCategory'] as String?;
      expect(
        suspectedCategory,
        isNotNull,
        reason: 'parser requires suspectedCategory',
      );
      return TriageResultFields(
        classification: DefectClassification.fromWire(classificationStr!),
        status: DefectStatus.fromWire(statusStr!),
        confidence: confidence!,
        suspectedCategory: suspectedCategory!,
        suspectedComponents:
            (structured['suspectedComponents'] as List?)?.cast<String>() ??
            const [],
        reproductionSupported:
            structured['reproductionSupported'] as bool? ?? false,
        evidenceUsed:
            (structured['evidenceUsed'] as List?)?.cast<String>() ?? const [],
        clarificationRequired: [
          for (final c in (structured['clarificationRequired'] as List?) ?? [])
            DefectClarificationRequest.fromJson(c as Map<String, dynamic>),
        ],
        recommendedNextAction:
            structured['recommendedNextAction'] as String? ?? 'investigate',
        recommendedWorkItemCategory:
            structured['recommendedWorkItemCategory'] as String?,
        summary: structured['summary'] as String? ?? 'Triage completed',
      );
    }

    test(
      'streamed triage transcript yields a parser-consumable result',
      () async {
        // The prompt at packages/scheduler/lib/src/triage_defect.dart asks for a
        // bare JSON object; a realistic runtime still delivers it as text, in
        // several chunks, after a line of preamble.
        final result = await _runTriageTurn([
          _chunk('Triage complete.\n'),
          _chunk(
            '{"classification":"IMPLEMENTATION_DEFECT","status":"triaged",'
            '"confidence":0.62,',
          ),
          _chunk(
            '"suspectedCategory":"backend",'
            '"suspectedComponents":["triage_processor"],'
            '"reproductionSupported":false,"evidenceUsed":["ev-1"],'
            '"clarificationRequired":[{"question":"Which tenant?",'
            '"reason":"Repro differs per tenant"}],'
            '"recommendedNextAction":"fix",'
            '"recommendedWorkItemCategory":"bug",'
            '"summary":"The defect appears to be in the triage processor."}',
          ),
          // The runtime also reports the complete message; it must not double up
          // the extracted payload or the summary.
          _message('{"classification":"IMPLEMENTATION_DEFECT"}'),
        ]);

        expect(result.status, equals(AgentResultStatus.completed));
        final structured = result.structuredResult;
        expect(structured, isNotEmpty);
        expect(result.metadata?['structuredResultPresent'], isTrue);
        expect(result.metadata?['stopReason'], equals('end_turn'));

        final parsed = parseLikeTriageProcessor(structured);
        expect(
          parsed.classification,
          DefectClassification.implementationDefect,
        );
        expect(parsed.status, DefectStatus.triaging);
        expect(parsed.confidence, closeTo(0.62, 1e-9));
        expect(parsed.suspectedCategory, equals('backend'));
        expect(parsed.suspectedComponents, equals(['triage_processor']));
        expect(parsed.reproductionSupported, isFalse);
        expect(parsed.evidenceUsed, equals(['ev-1']));
        expect(parsed.clarificationRequired.single.question, 'Which tenant?');
        expect(
          parsed.clarificationRequired.single.reason,
          'Repro differs per tenant',
        );
        expect(parsed.recommendedNextAction, equals('fix'));
        expect(parsed.recommendedWorkItemCategory, equals('bug'));
        expect(parsed.summary, contains('triage processor'));

        // The raw final text stays visible to a human, from the stream only.
        expect(result.summary, startsWith('Triage complete.'));
        expect(result.summary, contains('"classification"'));
        expect(result.metadata?['chunkCount'], equals(3));
      },
    );

    test('extracts a fenced payload wrapped in prose', () async {
      final result = await _runTriageTurn([
        _chunk(
          'Here is the analysis.\n\n```json\n'
          '{"classification":"design_defect","status":"triaging",'
          '"confidence":0.7,"suspectedCategory":"UI",'
          '"suspectedComponents":["nav"],"reproductionSupported":true,'
          '"evidenceUsed":[],"clarificationRequired":[],'
          '"recommendedNextAction":"clarify","summary":"Spec is unclear."}\n'
          '```\nDone.',
        ),
      ]);

      final parsed = parseLikeTriageProcessor(result.structuredResult);
      expect(parsed.classification, DefectClassification.designDefect);
      expect(parsed.status, DefectStatus.triaging);
      expect(parsed.confidence, closeTo(0.7, 1e-9));
    });

    test('unwraps a double-encoded JSON string payload', () async {
      final result = await _runTriageTurn([
        _chunk(
          '"{\\"classification\\":\\"environment_defect\\",'
          '\\"status\\":\\"triaging\\",\\"confidence\\":0.4,'
          '\\"suspectedCategory\\":\\"infrastructure\\",'
          '\\"suspectedComponents\\":[],\\"reproductionSupported\\":false,'
          '\\"evidenceUsed\\":[],\\"clarificationRequired\\":[],'
          '\\"recommendedNextAction\\":\\"investigate\\",'
          '\\"summary\\":\\"Env mismatch.\\"}"',
        ),
      ]);

      final parsed = parseLikeTriageProcessor(result.structuredResult);
      expect(parsed.classification, DefectClassification.environmentDefect);
      expect(parsed.confidence, closeTo(0.4, 1e-9));
    });

    test('keeps a brace inside a JSON string from ending the object', () async {
      final result = await _runTriageTurn([
        _chunk(
          'Result: {"classification":"requirement_gap","status":"triaging",'
          '"confidence":0.5,"suspectedCategory":"specification",'
          '"suspectedComponents":[],"reproductionSupported":false,'
          '"evidenceUsed":[],"clarificationRequired":[],'
          '"recommendedNextAction":"clarify",'
          '"summary":"Expected behavior says {unknown}."}',
        ),
      ]);

      final parsed = parseLikeTriageProcessor(result.structuredResult);
      expect(parsed.classification, DefectClassification.requirementGap);
      expect(parsed.summary, contains('{unknown}'));
    });

    test(
      'falls back to a complete agent_message when nothing streamed',
      () async {
        final result = await _runTriageTurn([
          _message(
            '{"classification":"implementation_defect","status":"triaging",'
            '"confidence":0.9,"suspectedCategory":"backend",'
            '"suspectedComponents":["api"],"reproductionSupported":true,'
            '"evidenceUsed":["ev-9"],"clarificationRequired":[],'
            '"recommendedNextAction":"fix","summary":"Null deref in api."}',
          ),
        ]);

        expect(result.metadata?['chunkCount'], equals(0));
        final parsed = parseLikeTriageProcessor(result.structuredResult);
        expect(parsed.confidence, closeTo(0.9, 1e-9));
        expect(result.summary, contains('Null deref in api.'));
      },
    );

    test('leaves an unrecognised classification token untouched', () async {
      final result = await _runTriageTurn([
        _chunk(
          '{"classification":"MARTIAN_DEFECT","status":"triaged",'
          '"confidence":0.1,"suspectedCategory":"unknown",'
          '"suspectedComponents":[],"reproductionSupported":false,'
          '"evidenceUsed":[],"clarificationRequired":[],'
          '"recommendedNextAction":"escalate","summary":"Not sure."}',
        ),
      ]);

      // Re-encoded spelling only: the agent's own token survives, and the
      // parser is left to reject it rather than the adapter inventing one.
      expect(result.structuredResult['classification'], 'MARTIAN_DEFECT');
      expect(
        () => DefectClassification.fromWire(
          result.structuredResult['classification'] as String,
        ),
        throwsFormatException,
      );
    });

    test('a transcript with no usable payload stays honestly empty', () async {
      final result = await _runTriageTurn([
        _chunk('I could not determine a classification from the evidence.\n'),
      ]);

      expect(result.status, equals(AgentResultStatus.completed));
      expect(result.structuredResult, isEmpty);
      expect(result.metadata?['structuredResultPresent'], isFalse);
      // The raw text is still surfaced so a human can see what the agent said.
      expect(result.summary, contains('could not determine'));
      final warnings = result.diagnostics.warnings;
      expect(warnings.map((w) => w.code), contains('structured_result_absent'));
      expect(warnings.single.severity, equals('warning'));
      // A completed turn is not reported as an error.
      expect(result.diagnostics.errors, isEmpty);
      expect(result.diagnostics.exitCode, equals(0));
    });

    test('an empty transcript yields an empty result and a warning', () async {
      final result = await _runTriageTurn(const []);

      expect(result.status, equals(AgentResultStatus.completed));
      expect(result.structuredResult, isEmpty);
      expect(result.summary, isNull);
      expect(
        result.diagnostics.warnings.map((w) => w.code),
        contains('structured_result_absent'),
      );
    });
  });
}

/// The subset of `TriageResult` fields the app-side parser builds, populated
/// with the parser's own contract calls.
class TriageResultFields {
  TriageResultFields({
    required this.classification,
    required this.status,
    required this.confidence,
    required this.suspectedCategory,
    required this.suspectedComponents,
    required this.reproductionSupported,
    required this.evidenceUsed,
    required this.clarificationRequired,
    required this.recommendedNextAction,
    required this.recommendedWorkItemCategory,
    required this.summary,
  });

  final DefectClassification classification;
  final DefectStatus status;
  final double confidence;
  final String suspectedCategory;
  final List<String> suspectedComponents;
  final bool reproductionSupported;
  final List<String> evidenceUsed;
  final List<DefectClarificationRequest> clarificationRequired;
  final String recommendedNextAction;
  final String? recommendedWorkItemCategory;
  final String summary;
}
