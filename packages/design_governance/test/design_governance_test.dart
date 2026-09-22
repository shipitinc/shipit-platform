import 'package:design_governance/design_governance.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryDesignGovernanceStore basic functionality', () {
    late InMemoryDesignGovernanceStore store;

    setUp(() {
      store = InMemoryDesignGovernanceStore();
    });

    test('can instantiate store', () {
      expect(store, isA<DesignGovernanceStore>());
    });

    test('inTransaction executes body', () async {
      var executed = false;
      await store.inTransaction((tx) async {
        executed = true;
      });
      expect(executed, isTrue);
    });
  });
}