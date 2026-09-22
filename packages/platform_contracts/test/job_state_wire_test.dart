import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('JobState wire contract is pinned to what is already persisted', () {
    test('wire values match the historical .name spellings exactly', () {
      // These strings are in the database and in the
      // `job_active_dedupe_unique` partial index predicate. Changing one is a
      // data migration plus an index rebuild, not a rename.
      expect({for (final s in JobState.values) s.name: s.wire}, {
        'queued': 'queued',
        'claimed': 'claimed',
        'running': 'running',
        'retryWaiting': 'retryWaiting',
        'succeeded': 'succeeded',
        'failed': 'failed',
        'cancelled': 'cancelled',
      });
    });

    test('the four active states named by the dedupe index still exist', () {
      // The partial index is ON job(dedupeKey) WHERE state IN (...these...).
      const indexed = {'queued', 'claimed', 'running', 'retryWaiting'};
      final active =
          JobState.values.where((s) => s.isActive).map((s) => s.wire).toSet();
      expect(active, indexed);
    });

    test('round-trips, and rejects unknown values loudly', () {
      for (final s in JobState.values) {
        expect(JobState.fromWire(s.wire), s);
      }
      expect(() => JobState.fromWire('retry_waiting'), throwsFormatException);
    });
  });
}
