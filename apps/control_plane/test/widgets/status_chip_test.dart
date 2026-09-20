import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_plane/shared/status_chip.dart';

void main() {
  group('StatusChip', () {
    testWidgets('renders with correct label and type', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusChip(label: 'RUNNING', type: StatusType.running),
          ),
        ),
      );

      expect(find.text('RUNNING'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('has semantic label for accessibility', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusChip(label: 'SUCCESS', type: StatusType.success),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.text('SUCCESS'));
      expect(semantics.label, contains('Status: SUCCESS'));
    });

    testWidgets('renders different types correctly', (tester) async {
      for (final type in StatusType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatusChip(label: type.name.toUpperCase(), type: type),
            ),
          ),
        );

        expect(find.text(type.name.toUpperCase()), findsOneWidget);
      }
    });
  });
}
