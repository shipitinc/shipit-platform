import 'dart:convert';

import 'package:control_plane_client/control_plane_client.dart';
import 'package:test/test.dart';

/// `DecisionView.metadataJson` carries the decision's free-form metadata as
/// JSON TEXT — the convention the other `*Json` fields on this wire already
/// use — because that is where an `engineering_review` decision ships its
/// `engineeringReviewResult`. These tests pin the round trip: the field
/// survives serialization intact, is omitted when absent, and decodes back
/// to exactly what the server stored.
void main() {
  DecisionView view({String? metadataJson}) => DecisionView(
    decisionId: 'dec-1',
    workItemId: 'WI-1',
    workItemTitle: 'A run',
    decisionType: 'engineering_review',
    status: 'pending',
    blocking: true,
    metadataJson: metadataJson,
  );

  const reviewMetadata = {
    'engineeringReviewResult': {
      'reviewExecutionId': 'exec-1',
      'verdict': 'approved_with_minor_findings',
      'findings': [
        {'severity': 'major', 'affectedSurface': 'lib/x.dart'},
      ],
    },
    'reviewExecutionId': 'exec-1',
    'reviewVerdict': 'approved_with_minor_findings',
  };

  test('metadataJson round-trips through toJson/fromJson intact', () {
    final wire = view(metadataJson: jsonEncode(reviewMetadata)).toJson();
    expect(wire['metadataJson'], isA<String>());

    final restored = DecisionView.fromJson(wire);
    expect(restored.metadataJson, isNotNull);
    expect(jsonDecode(restored.metadataJson!), reviewMetadata);
  });

  test('a decision without metadata omits the key and reads null', () {
    final wire = view().toJson();
    expect(wire.containsKey('metadataJson'), isFalse);
    expect(DecisionView.fromJson(wire).metadataJson, isNull);
  });
}
