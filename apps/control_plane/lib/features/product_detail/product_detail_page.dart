import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/product_language.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/design_primitives.dart';
import '../../shared/form_primitives.dart';
import '../../shared/mobile_chrome.dart';
import '../../shared/state_views.dart';
import 'product_detail_bloc.dart';

/// The "Product Detail" screen.
///
/// Transcribed from the Penpot board `BP · Product Detail` (light/dark):
/// breadcrumb, title, a status meta line, a left column of facts, the
/// accepted-baseline panel, the product history, and a right-hand Governance
/// panel carrying the active baseline, deploy key, standing policy and the
/// operator actions.
///
/// Governance actions are derived from durable state — an action that the
/// engine would refuse is not rendered at all, rather than shown and then
/// failing on tap.
class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, required this.productId, this.bloc});

  final String productId;

  /// Test-only dependency seam.
  final ProductDetailBloc? bloc;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<ProductDetailBloc>.value(
            value: provided,
            child: BlocListener<ProductDetailBloc, ProductDetailState>(
              listener: (context, state) {
                final decision = state.pendingDecision;
                if (decision != null) {
                  context.go('/needs-you/${decision.decisionId}');
                }
              },
              child: _ProductDetailView(productId: productId),
            ),
          )
        : BlocProvider<ProductDetailBloc>(
            create: (_) =>
                ProductDetailBloc(repository: ClientProvider.repository)
                  ..add(ProductDetailLoaded(productId)),
            child: _ProductDetailView(productId: productId),
          );
  }
}

/// The baseline-approval human gate.
///
/// Baseline decisions are scoped to `product-baseline:<productId>` rather than
/// a WorkItem row, so this gate cannot be reached through the needs-you
/// decision surface — it is resolved here instead.
///
/// Nothing is pre-selected and nothing is auto-approved: the operator must
/// choose an outcome and record a rationale, because the rationale is part of
/// the durable [HumanDecision] (AGENTS.md §11). Approving is the only choice
/// that accepts the baseline and makes the product dispatchable.
class _BaselineApprovalGate extends StatefulWidget {
  const _BaselineApprovalGate({
    required this.detail,
    required this.isResolving,
    required this.onResolve,
  });

  final ProductDetailResponse detail;
  final bool isResolving;

  /// Called with the wire choice and the operator's rationale.
  final void Function(String choice, String rationale) onResolve;

  @override
  State<_BaselineApprovalGate> createState() => _BaselineApprovalGateState();
}

class _BaselineApprovalGateState extends State<_BaselineApprovalGate> {
  String? _choice;
  String _rationale = '';

  bool get _canSubmit =>
      _choice != null && _rationale.trim().isNotEmpty && !widget.isResolving;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final d = widget.detail;
    return DesignPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'A baseline needs your approval',
                style: ShipItType.sectionTitle.copyWith(
                  color: palette.inkPrimary,
                ),
              ),
              const SizedBox(width: 10),
              AccentTick(color: palette.accent, height: 11),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${d.pendingBaselineId} · revision ${d.pendingBaselineRevision} · '
            'verified independently by a worker. Until you approve it, '
            '${d.productId} cannot dispatch work.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 18),
          const ContentRule(),
          const SizedBox(height: 14),
          MicroLabel('WHAT THIS BASELINE SAYS ABOUT ${d.name.toUpperCase()}'),
          const SizedBox(height: 8),
          _BaselineFacts(facts: d.pendingBaselineFacts),
          const SizedBox(height: 18),
          const MicroLabel('YOUR RATIONALE'),
          const SizedBox(height: 8),
          TextAreaBox(
            hintText:
                'Record why you accept this understanding of the product. '
                'This is stored with the decision.',
            onChanged: (v) => setState(() => _rationale = v),
          ),
          const SizedBox(height: 16),
          const MicroLabel('OUTCOME'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _ChoiceLink(
                label: 'Approve baseline',
                selected: _choice == 'approve',
                onTap: widget.isResolving
                    ? null
                    : () => setState(() => _choice = 'approve'),
              ),
              _ChoiceLink(
                label: 'Request correction',
                selected: _choice == 'request_correction',
                onTap: widget.isResolving
                    ? null
                    : () => setState(() => _choice = 'request_correction'),
              ),
              _ChoiceLink(
                label: 'Reject baseline',
                selected: _choice == 'reject',
                onTap: widget.isResolving
                    ? null
                    : () => setState(() => _choice = 'reject'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Only approval accepts this exact revision. The other outcomes '
            'are recorded without accepting.',
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
          const SizedBox(height: 16),
          if (!_canSubmit && !widget.isResolving)
            Text(
              'Choose an outcome and record a rationale to continue.',
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            ),
          const SizedBox(height: 10),
          _GateSubmit(
            label: widget.isResolving
                ? 'Recording your decision…'
                : 'Record decision',
            enabled: _canSubmit,
            onTap: () => widget.onResolve(_choice!, _rationale.trim()),
          ),
        ],
      ),
    );
  }
}

/// A single selectable outcome in the gate. Reads as a link until chosen.
class _ChoiceLink extends StatelessWidget {
  const _ChoiceLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CustomPaint(
                  painter: _ChoiceDotPainter(
                    selected: selected,
                    enabled: onTap != null,
                    color: palette.accent,
                    idle: palette.inkTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: ShipItType.link.copyWith(
                  color: selected ? palette.accent : palette.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceDotPainter extends CustomPainter {
  const _ChoiceDotPainter({
    required this.selected,
    required this.enabled,
    required this.color,
    required this.idle,
  });

  final bool selected;
  final bool enabled;
  final Color color;
  final Color idle;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = enabled ? color : idle;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = stroke;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1,
      paint,
    );
    if (selected) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2 - 4,
        Paint()..color = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ChoiceDotPainter old) =>
      old.selected != selected ||
      old.enabled != enabled ||
      old.color != color ||
      old.idle != idle;
}

/// The gate's commit action. Disabled until the decision is actually formable.
class _GateSubmit extends StatelessWidget {
  const _GateSubmit({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = enabled ? palette.accent : palette.inkTertiary;
    return Semantics(
      button: true,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(
                color: enabled ? palette.accent : palette.rule,
              ),
            ),
            child: Text(
              label,
              style: ShipItType.monoMeta.copyWith(
                color: fg,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductDetailView extends StatelessWidget {
  const _ProductDetailView({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailBloc, ProductDetailState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const DesignLoadingSkeleton(title: 'Product');
        }
        if (state.errorMessage != null) {
          return DesignErrorState(
            title: "We could not reach the system's records.",
            detail: state.errorMessage!,
            onRetry: () => context.read<ProductDetailBloc>().add(
              ProductDetailLoaded(productId),
            ),
          );
        }
        final detail = state.detail;
        if (detail == null) {
          return const DesignErrorState(
            title: 'That product is not in the registry.',
            detail: 'Nothing is recorded under this reference.',
          );
        }

        final status = state.status;
        final live = detail.policies.where((p) => !p.isRevoked).toList();
        final actions = GovernanceAction.availableFor(
          status,
          hasLivePolicy: live.isNotEmpty,
          hasPendingBaseline: detail.pendingBaselineId != null,
        );

        if (isMobile(context)) {
          return _MobileDetail(detail: detail, status: status, live: live);
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ShipItMetrics.contentGutter,
              26,
              ShipItMetrics.contentGutter,
              23,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InlineLink(
                  label: 'Products',
                  onTap: () => context.go('/products'),
                ),
                const SizedBox(height: 8),
                Text(
                  detail.name,
                  style: ShipItType.pageTitle.copyWith(
                    color: context.palette.inkPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _StatusLine(detail: detail, status: status),
                const SizedBox(height: 14),
                const ContentRule(),
                const SizedBox(height: 22),
                if (state.canApproveBaseline) ...[
                  _BaselineApprovalGate(
                    detail: detail,
                    isResolving: state.isResolvingBaseline,
                    onResolve: (choice, rationale) =>
                        context.read<ProductDetailBloc>().add(
                          BaselineApprovalResolved(
                            productId: detail.productId,
                            choice: choice,
                            rationale: rationale,
                          ),
                        ),
                  ),
                  const SizedBox(height: 22),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _LeftColumn(detail: detail, status: status),
                    ),
                    const SizedBox(width: ShipItMetrics.sidePanelGap),
                    SizedBox(
                      width: ShipItMetrics.sidePanelWidth,
                      child: _GovernancePanel(
                        detail: detail,
                        status: status,
                        livePolicies: live,
                        actions: actions,
                        onGovernance: (action) =>
                            context.read<ProductDetailBloc>().add(
                              GovernanceActionRequested(
                                action,
                                detail.productId,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                TechnicalDetails(
                  note:
                      'Read from the registry. FACTS counts recorded baseline '
                      'claims, not files.',
                  lines: _technicalLines(detail, live),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static List<String> _technicalLines(
    ProductDetailResponse d,
    List<PolicyResponse> live,
  ) => [
    'Product.state=${d.state} · allowsDispatch=${d.allowsDispatch}',
    if (d.activeBaselineId != null)
      'active baseline ${d.activeBaselineId} r${d.activeBaselineRevision} · '
          'hash ${d.activeBaselineHash} · '
          '${d.activeBaselineFactCount} facts · '
          'accepted by ${d.activeBaselineAcceptedBy ?? 'unknown'}'
    else
      'no accepted baseline — this product is not governed',
    if (d.pendingBaselineId != null)
      'pending baseline ${d.pendingBaselineId} r${d.pendingBaselineRevision} · '
          'independentlyVerified=${d.pendingBaselineVerified}',
    for (final c in d.credentials)
      '${c.referenceName} · ${c.algorithm} ${c.fingerprint} · '
          'status=${c.status} · hostKey=${c.hostKeyStatus} · '
          'canReach=${c.canReachRepository}'
          '${c.lastFailureReason == null ? '' : ' · last failure: ${c.lastFailureReason}'}',
    for (final p in live)
      'policy ${p.policyId} authorises ${p.actions.join(", ")} · '
          'cites decision ${p.authorisingDecisionId} · '
          'signed by ${p.authorisedBy}',
    for (final p in d.policies.where((p) => p.isRevoked))
      'policy ${p.policyId} REVOKED by ${p.revokedBy ?? 'unknown'} · '
          'reason ${p.revocationReason ?? 'unrecorded'}',
  ];
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.detail, required this.status});

  final ProductDetailResponse detail;
  final ProductStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        AccentTick(color: status.tickColor(palette), height: 11),
        const SizedBox(width: 8),
        Text(
          status.label.toUpperCase(),
          style: ShipItType.microLabel.copyWith(
            color: status.textColor(palette),
          ),
        ),
        const SizedBox(width: 18),
        Text(
          'ref ${detail.productId}',
          style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
        ),
        if (detail.activeBaselineRevision != null) ...[
          const SizedBox(width: 18),
          Text(
            'revision ${detail.activeBaselineRevision}',
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
        ],
      ],
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.detail, required this.status});

  final ProductDetailResponse detail;
  final ProductStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _heading(status),
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          status.detail,
          style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
        ),
        const SizedBox(height: 18),
        DefinitionList(entries: _facts(detail, status)),
        const SizedBox(height: 26),
        _AccessBlock(detail: detail),
        if (detail.openClarifications.isNotEmpty) ...[
          const SizedBox(height: 26),
          _ClarificationsBlock(items: detail.openClarifications),
        ],
      ],
    );
  }

  static String _heading(ProductStatus status) => switch (status) {
    ProductStatus.governed => 'What this product is',
    ProductStatus.paused => 'This product is paused',
    ProductStatus.archived => 'This product is archived',
    _ => 'Where this product got to',
  };

  static List<DefinitionEntry> _facts(
    ProductDetailResponse d,
    ProductStatus status,
  ) => [
    DefinitionEntry(
      label: 'WHAT THIS IS ABOUT',
      value: d.description?.isNotEmpty == true ? d.description! : d.name,
      ref: 'ref ${d.productId}',
    ),
    DefinitionEntry(label: 'STATUS', value: status.detail),
    DefinitionEntry(
      label: 'ACTIVE BASELINE',
      value: d.activeBaselineId == null
          // Said plainly rather than left blank: no baseline is why the
          // product is not governed.
          ? 'None accepted — nothing is governed yet'
          : '${d.activeBaselineId} · revision ${d.activeBaselineRevision}',
    ),
    DefinitionEntry(
      label: "WHAT'S UNDER GOVERNANCE",
      value: d.activeBaselineId == null
          ? 'Nothing yet'
          : '${d.activeBaselineFactCount} recorded facts · '
                'content hash ${d.activeBaselineHash}',
    ),
    if (d.pendingBaselineId != null)
      DefinitionEntry(
        label: 'PROPOSED BASELINE',
        value:
            '${d.pendingBaselineId} · revision ${d.pendingBaselineRevision}'
            '${d.pendingBaselineVerified ? ' · verified independently' : ' · NOT verified — the gate cannot open'}',
      ),
  ];
}

/// Per-repository credentials. States what is true, including when nothing is.
class _AccessBlock extends StatelessWidget {
  const _AccessBlock({required this.detail});

  final ProductDetailResponse detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Access',
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'One key per repository. The private half stays in the secret manager.',
          style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
        ),
        const SizedBox(height: 12),
        const ContentRule(strong: true),
        if (detail.repositories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'No repository is attributed to this product.',
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            ),
          )
        else
          for (final repo in detail.repositories)
            _CredentialRow(
              repo: repo,
              credential: detail.credentials
                  .where((c) => c.repositoryId == repo.repositoryId)
                  .firstOrNull,
            ),
      ],
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.repo, required this.credential});

  final ProductRepositoryResponse repo;
  final CredentialResponse? credential;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final c = credential;
    final (label, tone) = _access(c, palette);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccentTick(color: tone, height: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repo.uri,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShipItType.rowTitle.copyWith(
                        color: palette.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c == null
                          ? 'no key generated'
                          : '${c.referenceName} · ${c.algorithm} '
                                '${c.fingerprint}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShipItType.monoMeta.copyWith(
                        color: palette.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: ShipItType.status.copyWith(color: tone),
                ),
              ),
            ],
          ),
        ),
        const ContentRule(),
      ],
    );
  }

  /// Access is reported as a proven fact or an explicit obstacle — never as a
  /// reassuring default.
  (String, Color) _access(CredentialResponse? c, ShipItPalette palette) {
    if (c == null) return ('no key', palette.attention);
    if (c.hostKeyStatus == 'changed') {
      return ('host key CHANGED', palette.negative);
    }
    if (c.hostKeyStatus == 'unknown') {
      return ('host not confirmed', palette.attention);
    }
    if (c.status == 'revoked') return ('revoked', palette.inkTertiary);
    if (c.status == 'failing') {
      return (c.lastFailureReason ?? 'last check failed', palette.negative);
    }
    if (c.canReachRepository) return ('verified', palette.positive);
    return ('not checked yet', palette.attention);
  }
}

class _ClarificationsBlock extends StatelessWidget {
  const _ClarificationsBlock({required this.items});

  final List<ClarificationSummary> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Waiting on an answer',
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Onboarding stopped because something is not known. It resumes once '
          'you answer.',
          style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
        ),
        const SizedBox(height: 12),
        const ContentRule(strong: true),
        for (final item in items)
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AccentTick(color: palette.attentionTick, height: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.question,
                        style: ShipItType.rowTitle.copyWith(
                          color: palette.inkPrimary,
                        ),
                      ),
                    ),
                    Text(
                      item.section,
                      style: ShipItType.monoMeta.copyWith(
                        color: palette.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const ContentRule(),
            ],
          ),
      ],
    );
  }
}

class _GovernancePanel extends StatelessWidget {
  const _GovernancePanel({
    required this.detail,
    required this.status,
    required this.livePolicies,
    required this.actions,
    required this.onGovernance,
  });

  final ProductDetailResponse detail;
  final ProductStatus status;
  final List<PolicyResponse> livePolicies;
  final List<GovernanceAction> actions;

  /// Dispatches the gate raise back to the bloc. The panel never resolves
  /// decisions itself — durable governance stays in one place.
  final ValueChanged<GovernanceAction> onGovernance;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final policy = livePolicies.firstOrNull;
    final credential = detail.credentials.firstOrNull;
    return DesignPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Governance',
            style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            _panelSub(status),
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 18),
          const ContentRule(),
          const SizedBox(height: 16),
          _PanelEntry(
            label: 'ACTIVE BASELINE',
            value: detail.activeBaselineId == null
                ? 'None accepted'
                : '${detail.activeBaselineId} · accepted'
                      '${detail.activeBaselineAcceptedBy == null ? '' : ' by ${detail.activeBaselineAcceptedBy}'}',
          ),
          const SizedBox(height: 14),
          _PanelEntry(
            label: 'DEPLOY KEY',
            value: credential == null
                ? 'None — this product cannot be reached'
                : '${credential.fingerprint}'
                      '${credential.canReachRepository ? '' : ' · not usable'}',
          ),
          const SizedBox(height: 14),
          _PanelEntry(
            label: 'STANDING POLICY',
            // The citation: which signed decision authorises unattended work.
            value: policy == null
                ? status == ProductStatus.governed
                      ? 'None — every push waits for you'
                      : 'None — available once this product is governed'
                : '${policy.actions.join(" and ")} · authorised by '
                      '${policy.authorisedBy} · ref '
                      '${policy.authorisingDecisionId}',
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const ContentRule(),
            const SizedBox(height: 14),
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InlineLink(
                  label: action.label,
                  onTap: () => onGovernance(action),
                ),
              ),
          ],
          if (status == ProductStatus.archived) ...[
            const SizedBox(height: 16),
            Text(
              'Archived products keep every decision, run and piece of '
              'evidence. Nothing is deleted.',
              style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
            ),
          ],
        ],
      ),
    );
  }

  static String _panelSub(ProductStatus status) => switch (status) {
    ProductStatus.governed =>
      'This product is governed. New work must fit the accepted baseline.',
    ProductStatus.paused => 'Work is paused. The baseline is still accepted.',
    ProductStatus.archived =>
      'Archived. No new work can be created or dispatched.',
    _ => 'Not governed yet. Approve a baseline to let work start.',
  };
}

class _PanelEntry extends StatelessWidget {
  const _PanelEntry({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MicroLabel(label),
        const SizedBox(height: 4),
        Text(
          value,
          style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
        ),
      ],
    );
  }
}

/// The platform's fixed baseline section order, so a baseline reads the same
/// way every time instead of in whatever order discovery happened to emit.
const _baselineSectionOrder = <String>[
  'repository',
  'tech_stack',
  'architecture',
  'design',
  'qa',
  'ci_cd',
  'environments',
  'data',
  'deployment',
  'governance',
  'known_gaps',
];

/// Sections whose wire names are acronyms, which title-casing alone renders as
/// nonsense ("Qa", "Ci Cd").
const _sectionLabels = <String, String>{'qa': 'QA', 'ci_cd': 'CI/CD'};

String _humaniseWire(String wire) {
  final override = _sectionLabels[wire];
  if (override != null) return override;
  return wire
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// The claims the pending candidate makes, grouped by section.
///
/// Approving binds the operator to this exact content, so it has to be on
/// screen — a reviewer cannot consent to a hash. Sections are ordered by the
/// platform's fixed section order rather than by arrival, and the maturity
/// mix is stated up front because a baseline heavy in `unknown` is a different
/// decision from a fully evidenced one.
class _BaselineFacts extends StatefulWidget {
  const _BaselineFacts({required this.facts});

  final List<BaselineFactClaim> facts;

  @override
  State<_BaselineFacts> createState() => _BaselineFactsState();
}

class _BaselineFactsState extends State<_BaselineFacts> {
  /// Long baselines are not read line by line, so the list starts collapsed to
  /// a summary and expands on request. Nothing is hidden from the decision: the
  /// count and the section breakdown are always shown.
  static const _previewLimit = 12;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final facts = widget.facts;

    if (facts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: palette.negative)),
        child: Text(
          'This candidate asserts nothing. It has no facts, so approving it '
          'would govern the product with no understanding of it to govern '
          'against. Request a correction instead.',
          style: ShipItType.bodySmall.copyWith(color: palette.negative),
        ),
      );
    }

    final bySection = <String, List<BaselineFactClaim>>{};
    for (final f in facts) {
      bySection.putIfAbsent(f.section, () => []).add(f);
    }
    final sections = _baselineSectionOrder
        .where(bySection.containsKey)
        .followedBy(
          bySection.keys.where((k) => !_baselineSectionOrder.contains(k)),
        )
        .toList();

    final maturityCounts = <String, int>{};
    for (final f in facts) {
      maturityCounts[f.maturity] = (maturityCounts[f.maturity] ?? 0) + 1;
    }
    final maturityLine = maturityCounts.entries
        .map((e) => '${_humaniseWire(e.key).toLowerCase()} ${e.value}')
        .join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${facts.length} claims across ${sections.length} '
          '${sections.length == 1 ? 'section' : 'sections'} · $maturityLine',
          style: ShipItType.monoMeta.copyWith(color: palette.inkSecondary),
        ),
        const SizedBox(height: 10),
        // The section index is always fully visible, so collapsing never hides
        // a section without saying so.
        Text(
          sections
              .map((s) => '${_humaniseWire(s)} ${bySection[s]!.length}')
              .join('  ·  '),
          style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
        ),
        const SizedBox(height: 10),
        if (_expanded)
          for (final section in sections) ...[
            MicroLabel(
              '${_humaniseWire(section).toUpperCase()} · '
              '${bySection[section]!.length}',
            ),
            const SizedBox(height: 6),
            for (final fact in bySection[section]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FactRow(fact: fact, showSection: false),
              ),
            const SizedBox(height: 6),
          ]
        else
          for (final fact in facts.take(_previewLimit))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FactRow(fact: fact, showSection: true),
            ),
        if (!_expanded && facts.length > _previewLimit)
          Text(
            'Showing first $_previewLimit of ${facts.length} claims.',
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
        const SizedBox(height: 2),
        _ChoiceLink(
          label: _expanded
              ? 'Collapse claims'
              : 'Read all ${facts.length} claims',
          selected: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
      ],
    );
  }
}

/// One claim, with the provenance and maturity that make it judgeable.
class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact, required this.showSection});

  final BaselineFactClaim fact;

  /// Collapsed preview spans sections, so it labels each row. The expanded
  /// view is already grouped under headings.
  final bool showSection;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // An assumed or unknown claim is not established fact, so it is marked
    // rather than presented in the same voice as an observed one.
    final tentative =
        fact.maturity == 'unknown' || fact.provenance == 'assumed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 9),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: tentative ? palette.attention : palette.accent,
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fact.claim,
            style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '${showSection ? '${_humaniseWire(fact.section)} · ' : ''}'
            '${fact.provenance} · ${fact.maturity}'
            '${fact.evidenceRefs.isEmpty ? '' : ' · ${fact.evidenceRefs.join(', ')}'}'
            '${fact.redacted ? ' · redacted' : ''}',
            style: ShipItType.monoMeta.copyWith(
              color: tentative ? palette.attention : palette.inkTertiary,
            ),
          ),
          if (fact.assumptionNote != null &&
              fact.assumptionNote!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Assumes: ${fact.assumptionNote}',
              style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileDetail extends StatelessWidget {
  const _MobileDetail({
    required this.detail,
    required this.status,
    required this.live,
  });

  final ProductDetailResponse detail;
  final ProductStatus status;
  final List<PolicyResponse> live;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        // The `Back` bar is shell chrome: AppShell renders it for
        // `/products/:id`, so drawing a second one here stacked it under the
        // brand bar and produced two top bars where the board has one.
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ShipItMetrics.mobileGutter,
                16,
                ShipItMetrics.mobileGutter,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.name,
                    style: ShipItType.pageTitle.copyWith(
                      color: palette.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      AccentTick(color: status.tickColor(palette), height: 11),
                      const SizedBox(width: 8),
                      Text(
                        status.label.toUpperCase(),
                        style: ShipItType.microLabel.copyWith(
                          color: status.textColor(palette),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const ContentRule(),
                  const SizedBox(height: 16),
                  DefinitionList(entries: _LeftColumn._facts(detail, status)),
                  const SizedBox(height: 22),
                  _AccessBlock(detail: detail),
                  const SizedBox(height: 22),
                  _GovernancePanel(
                    detail: detail,
                    status: status,
                    livePolicies: live,
                    actions: GovernanceAction.availableFor(
                      status,
                      hasLivePolicy: live.isNotEmpty,
                      hasPendingBaseline: detail.pendingBaselineId != null,
                    ),
                    onGovernance: (action) =>
                        context.read<ProductDetailBloc>().add(
                          GovernanceActionRequested(action, detail.productId),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
