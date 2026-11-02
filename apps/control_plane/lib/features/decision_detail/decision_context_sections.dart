import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../../core/plain_language.dart';
import '../../core/theme.dart';
import '../../shared/design_primitives.dart';
import 'decision_context.dart';
import 'decision_detail_bloc.dart';

/// The decisionType → renderer registry for the decision detail page.
///
/// A decision type that carries typed context in `metadataJson` registers
/// one renderer here (paired with one parser in
/// `decision_context.dart`'s `decisionContextParsers`), and the page's left
/// column renders whatever sections the type knows how to explain —
/// `engineering_review` renders the reviewer's verdict, its findings and
/// the artifact under review; a type with no renderer renders exactly the
/// generic record it always did. This is a map, not a switch, so the next
/// type is an entry, not an edit to the page.
abstract class DecisionDetailRenderer {
  const DecisionDetailRenderer();

  /// Extra left-column sections for this decision type, inserted after the
  /// definition list and before the consequence table. The generic
  /// renderer returns none — the existing sections are the default.
  List<Widget> contextSections(BuildContext context, DecisionDetailState state);
}

/// The fallback every type without a registered renderer gets.
class GenericDecisionDetailRenderer extends DecisionDetailRenderer {
  const GenericDecisionDetailRenderer();

  @override
  List<Widget> contextSections(
    BuildContext context,
    DecisionDetailState state,
  ) => const [];
}

/// Renders the record an `engineering_review` decision actually carries:
/// the full context the two-line definition row truncates, the reviewer's
/// verdict and findings, and the identity of the revision under review.
class EngineeringReviewDetailRenderer extends DecisionDetailRenderer {
  const EngineeringReviewDetailRenderer();

  @override
  List<Widget> contextSections(
    BuildContext context,
    DecisionDetailState state,
  ) {
    final payload = state.contextPayload;
    final review = payload is EngineeringReviewContext ? payload : null;
    return [
      if (state.workItemDescription?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 20),
        _FullContextSection(
          title: state.workItemTitle ?? state.runName,
          body: state.workItemDescription!.trim(),
        ),
      ],
      if (review != null && review.verdict != null) ...[
        const SizedBox(height: 20),
        _ReviewVerdictSection(review: review),
      ],
      if (review != null &&
          (review.revisionId != null || review.reviewExecutionId != null)) ...[
        const SizedBox(height: 20),
        _ReviewArtifactSection(review: review),
      ],
      if (review != null && review.unreadable && review.result == null) ...[
        const SizedBox(height: 20),
        _UnreadableReviewNote(),
      ],
    ];
  }
}

/// The registry itself. Adding a type is adding an entry — the page does
/// not change.
final Map<String, DecisionDetailRenderer> decisionDetailRenderers = {
  'engineering_review': const EngineeringReviewDetailRenderer(),
};

/// The renderer for [decisionTypeWire] — the generic one when the type has
/// no entry, so an unmapped wire can never break the page.
DecisionDetailRenderer decisionDetailRendererFor(String decisionTypeWire) =>
    decisionDetailRenderers[decisionTypeWire] ??
    const GenericDecisionDetailRenderer();

/// The whole story: the item's title as the header and its full recorded
/// description, where the definition row above shows at most two lines of
/// it. This is the panel a decider reads before the verdict.
class _FullContextSection extends StatelessWidget {
  const _FullContextSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MicroLabel('WHAT THIS IS ABOUT — IN FULL'),
        const SizedBox(height: 6),
        Text(
          title,
          style: ShipItType.rowTitle.copyWith(
            fontWeight: FontWeight.w600,
            color: palette.inkPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
        ),
      ],
    );
  }
}

/// The verdict badge and the findings behind it — what the reviewer
/// actually concluded, which is the thing the decider is being asked to
/// ratify or send back.
class _ReviewVerdictSection extends StatelessWidget {
  const _ReviewVerdictSection({required this.review});

  final EngineeringReviewContext review;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final verdict = review.verdict!;
    final accent = switch (verdict) {
      'approved' => palette.positive,
      'approved_with_minor_findings' => palette.positive,
      'changes_required' => palette.attention,
      'rejected' => palette.negative,
      _ => palette.inkSecondary,
    };
    final findings = review.result?.findings ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MicroLabel('REVIEW VERDICT'),
        const SizedBox(height: 8),
        _VerdictBadge(verdict: verdict, accent: accent),
        if (review.result != null &&
            review.result!.assessedDimensions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'assessed: ${review.result!.assessedDimensions.join(', ')}',
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
        ],
        if (findings.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final finding in findings) ...[
            _FindingCard(finding: finding),
            const SizedBox(height: 8),
          ],
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'The reviewer recorded no findings.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
        ],
      ],
    );
  }
}

/// A small verdict chip: positive for passing verdicts, attention for
/// changes required, negative for rejected, and the raw wire value — never
/// a friendlier invented word — when it is none of the four.
class _VerdictBadge extends StatelessWidget {
  const _VerdictBadge({required this.verdict, required this.accent});

  final String verdict;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent),
        borderRadius: BorderRadius.circular(ShipItMetrics.radius),
      ),
      child: Text(verdict, style: ShipItType.status.copyWith(color: accent)),
    );
  }
}

/// One finding: severity and category as labels, the evidence the reviewer
/// cited, the correction it requires, and the surface it found it on.
class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final ReviewFinding finding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final severityAccent = switch (finding.severity.wire) {
      'blocker' => palette.negative,
      'major' => palette.negative,
      'minor' => palette.attention,
      'advisory' => palette.inkSecondary,
      _ => palette.inkSecondary,
    };
    return DesignPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                finding.severity.wire,
                style: ShipItType.status.copyWith(color: severityAccent),
              ),
              const SizedBox(width: 10),
              Text(
                finding.category.wire,
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
            ],
          ),
          if (finding.evidence.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              finding.evidence,
              style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
            ),
          ],
          if (finding.requiredCorrection.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Required: ${finding.requiredCorrection}',
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
          ],
          if (finding.affectedSurface.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              finding.affectedSurface,
              style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

/// The artifact under review: the revision the reviewer assessed, the
/// execution that assessed it, and the surfaces its findings name. This is
/// the answer to "WHAT am I approving" — provenance, not prose.
class _ReviewArtifactSection extends StatelessWidget {
  const _ReviewArtifactSection({required this.review});

  final EngineeringReviewContext review;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final surfaces = <String>{
      for (final f in review.result?.findings ?? const <ReviewFinding>[])
        if (f.affectedSurface.trim().isNotEmpty) f.affectedSurface.trim(),
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MicroLabel('THE ARTIFACT UNDER REVIEW'),
        const SizedBox(height: 8),
        DefinitionList(
          entries: [
            if (review.revisionId != null)
              DefinitionEntry(
                label: 'REVISION',
                value: review.revisionId!,
                prose: true,
              ),
            if (review.reviewExecutionId != null)
              DefinitionEntry(
                label: 'REVIEWED BY EXECUTION',
                value: review.reviewExecutionId!,
                ref: PlainLanguage.refLabel(review.reviewExecutionId!),
              ),
          ],
        ),
        if (surfaces.isNotEmpty) ...[
          const SizedBox(height: 8),
          const MicroLabel('SURFACES THE FINDINGS NAME'),
          const SizedBox(height: 6),
          for (final surface in surfaces)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                surface,
                style: ShipItType.monoMeta.copyWith(color: palette.inkPrimary),
              ),
            ),
        ],
      ],
    );
  }
}

/// The record carried a review payload this build could not read. That is
/// itself shown — an unreadable review is never rendered as a clean one
/// and never mistaken for no review at all.
class _UnreadableReviewNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Text(
      'This decision carries a review record this build could not read. '
      'The verdict it recorded is not shown because it could not be '
      'verified against the stored payload.',
      style: ShipItType.bodySmall.copyWith(color: palette.attention),
    );
  }
}
