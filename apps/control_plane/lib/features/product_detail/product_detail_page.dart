import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/product_language.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/design_primitives.dart';
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
                context.go('/needs-you/\${decision.decisionId}');
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
                        onGovernance: (action) => context
                            .read<ProductDetailBloc>()
                            .add(
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
          'One key per repository. The private half never leaves this device.',
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
    return SingleChildScrollView(
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
              style: ShipItType.pageTitle.copyWith(color: palette.inkPrimary),
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
              onGovernance: (action) => context
                  .read<ProductDetailBloc>()
                  .add(
                    GovernanceActionRequested(
                      action,
                      detail.productId,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
