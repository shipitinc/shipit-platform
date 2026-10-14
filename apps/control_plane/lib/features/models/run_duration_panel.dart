import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../shared/design_primitives.dart';
import 'run_duration_stats.dart';

/// The "how long does a run actually take?" table.
///
/// ## Why it is here and not under Executions
///
/// The Executions page answers "what happened to this run". This answers "how
/// long does a run of this role take", which is a question about the BUDGETS
/// rather than about any one run — and the budgets live on this page, next to
/// the cost and token figures they spend.
///
/// ## What it deliberately does NOT show
///
/// A mean. The set is bimodal by construction — every run is either fast or
/// killed at its budget — so a mean is dominated by the ceiling and answers
/// nothing. [RunDurationBucket.medianSeconds] over the completed runs does.
///
/// And it does not merge the failures into the successes. A run that settled
/// `interrupted` is a run the platform killed, and after the coordinator change
/// that status means exactly "hit its budget". An operator reading this table
/// must be able to count those, because that count is what tells them whether
/// the budget is right.
class RunDurationPanel extends StatelessWidget {
  const RunDurationPanel({super.key, required this.stats, this.unmeasuredRuns});

  final RunDurationStats? stats;

  /// Runs in range with no usable duration. Null when the read failed.
  final int? unmeasuredRuns;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final failed = stats == null;
    if (failed) {
      return DesignPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Run Duration',
              style: ShipItType.sectionTitle.copyWith(
                color: palette.inkPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Durations could not be read from agent execution records. This is '
              'a failure to read, not an absence of runs — no duration is being '
              'claimed here.',
              style: ShipItType.bodySmall.copyWith(color: palette.attention),
            ),
          ],
        ),
      );
    }

    final table = stats!;
    return DesignPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Run Duration',
            style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Per agent role and terminal status, from agent_execution.startedAt '
            'and completedAt. Median, not mean: every run is either fast or '
            'killed at its budget, so a mean is dominated by the ceiling.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
          ),
          const SizedBox(height: 16),
          if (table.isEmpty)
            Text(
              'No completed agent runs in this range. Nothing is claimed about '
              'how long a run takes, because nothing ran.',
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            )
          else ...[
            for (final role in table.roles) ...[
              if (role != table.roles.first) const SizedBox(height: 18),
              _RoleBlock(
                role: role,
                buckets: table.forRoleSorted(role),
                palette: palette,
              ),
            ],
          ],
          if ((unmeasuredRuns ?? 0) > 0) ...[
            const SizedBox(height: 14),
            Text(
              '$unmeasuredRuns further run(s) in this range carry no usable '
              'duration (never finished, or the two timestamps disagree) and '
              'are excluded from these figures rather than counted as zero.',
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleBlock extends StatelessWidget {
  const _RoleBlock({
    required this.role,
    required this.buckets,
    required this.palette,
  });

  final String role;
  final List<RunDurationBucket> buckets;
  final ShipItPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MicroLabel(_humanise(role)),
        const SizedBox(height: 8),
        for (final bucket in buckets) ...[
          _DurationRow(bucket: bucket, palette: palette),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({required this.bucket, required this.palette});

  final RunDurationBucket bucket;
  final ShipItPalette palette;

  @override
  Widget build(BuildContext context) {
    final succeeded = bucket.isSuccess;
    final accent = succeeded ? palette.positive : palette.attention;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 3)),
        color: palette.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                succeeded ? 'completed' : bucket.status,
                style: ShipItType.bodySmall.copyWith(color: accent),
              ),
              const Spacer(),
              Text(
                '${bucket.count} run${bucket.count == 1 ? '' : 's'}',
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Stat(label: 'min', value: formatRunDuration(bucket.minSeconds)),
              _Stat(
                label: 'median',
                value: formatRunDuration(bucket.medianSeconds),
                emphasised: true,
              ),
              _Stat(label: 'max', value: formatRunDuration(bucket.maxSeconds)),
            ],
          ),
          if (bucket.isKilledAtBudget) ...[
            const SizedBox(height: 6),
            Text(
              'Settled `interrupted` — the shape an execution killed at its '
              'budget takes. '
              '${bucket.count} of these is the number that says whether the '
              'ceiling is set correctly.',
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            ),
          ] else if (bucket.isUniform && !succeeded) ...[
            const SizedBox(height: 6),
            Text(
              'Every sample in this bucket ran for exactly '
              '${formatRunDuration(bucket.minSeconds)}, which is the signature '
              'of a ceiling rather than of a slow run.',
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Expanded(
      child: Row(
        children: [
          Text(
            label,
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: (emphasised ? ShipItType.sectionTitle : ShipItType.bodySmall)
                .copyWith(
                  color: emphasised ? palette.inkPrimary : palette.inkSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

/// `engineering_reviewer` -> `Engineering reviewer`. Wire values are the storage
/// format; an operator reading a table should not have to know that.
String _humanise(String wire) {
  if (wire.isEmpty) return wire;
  final spaced = wire.replaceAll('_', ' ');
  return spaced[0].toUpperCase() + spaced.substring(1);
}
