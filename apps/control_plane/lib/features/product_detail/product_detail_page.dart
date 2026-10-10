import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  const ProductDetailPage({
    super.key,
    required this.productId,
    this.bloc,
    this.repository,
  });

  final String productId;

  /// Test-only dependency seam for the bloc itself.
  final ProductDetailBloc? bloc;

  /// Test-only seam for the repository the production branch constructs its
  /// bloc from.
  ///
  /// It exists because the production branch is the one that was broken: a
  /// `pendingDecision` navigation listener used to be mounted only when [bloc]
  /// was injected, so `pendingDecision` had no consumer in the real app. A
  /// test that injects a bloc therefore proves nothing about production. Both
  /// branches below render identically; only the repository differs.
  final ControlPlaneRepository? repository;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<ProductDetailBloc>.value(
            value: provided,
            child: _ProductDetailView(productId: productId),
          )
        : BlocProvider<ProductDetailBloc>(
            create: (_) => ProductDetailBloc(
              repository: repository ?? ClientProvider.repository,
            )..add(ProductDetailLoaded(productId)),
            child: _ProductDetailView(productId: productId),
          );
  }
}

/// The lifecycle human gate.
///
/// Raised and resolved in place, on this screen. Lifecycle decisions hang off
/// the synthetic scope `product-lifecycle:<productId>` rather than a WorkItem
/// row, so `DecisionDetailPage` cannot read one (`readWorkItem` throws for that
/// scope) and the needs-you board cannot list one. Routing here would leave a
/// `blocking: true` gate that nobody can action — the exact outcome
/// `product_registry_endpoints.dart:164-165` promises never to happen.
///
/// [gate] is what the REGISTRY says is open, re-read on every load. It is not
/// the return of the call that raised it, because that value dies with the
/// screen that made it, and a gate nobody can still reach is the failure this
/// panel exists to prevent.
///
/// Nothing is pre-selected: the operator chooses an outcome and records a
/// rationale, because the rationale is part of the durable `HumanDecision`
/// (AGENTS.md §11).
class _LifecycleDecisionGate extends StatefulWidget {
  const _LifecycleDecisionGate({
    required this.gate,
    required this.requiresWorkInFlightAssertion,
    required this.isResolving,
    required this.onResolve,
  });

  final LifecycleGateResponse gate;

  /// True for an offboard raised from `governed`/`paused`, where the engine
  /// requires `ProductGuard.noWorkInFlight`. Derived from the gate's own durable
  /// action, so an operator returning to an open offboard gate is still asked.
  final bool requiresWorkInFlightAssertion;
  final bool isResolving;

  /// Called with the wire choice, the rationale, and the operator's own
  /// no-work-in-flight statement.
  final void Function(String choice, String rationale, bool noWorkInFlight)
  onResolve;

  @override
  State<_LifecycleDecisionGate> createState() => _LifecycleDecisionGateState();
}

class _LifecycleDecisionGateState extends State<_LifecycleDecisionGate> {
  String? _choice;
  String _rationale = '';
  bool _attestsNoWorkInFlight = false;

  bool get _canSubmit {
    if (widget.isResolving) return false;
    if (_choice == null || _rationale.trim().isEmpty) return false;
    if (widget.requiresWorkInFlightAssertion && !_attestsNoWorkInFlight) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final decision = widget.gate;
    final options = decision.options ?? const <DecisionOption>[];
    return DesignPanel(
      edgeColor: palette.attentionTick,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'This action needs your decision',
                  style: ShipItType.sectionTitle.copyWith(
                    color: palette.inkPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AccentTick(color: palette.attentionTick, height: 11),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            // The engine's own question. The fallback exists only for a gate
            // raised without one; it never guesses at the action, because a
            // guess here would be the screen describing a decision it did not
            // read.
            decision.question ??
                'This product has a lifecycle decision to record.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'ref ${decision.decisionId} · raised against '
            '${decision.context?.workflowState ?? 'the current state'} · '
            '${decision.blocking ? 'blocking until you decide' : 'advisory'}',
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
          const SizedBox(height: 18),
          const ContentRule(),
          const SizedBox(height: 14),
          const MicroLabel('WHAT EACH OUTCOME DOES'),
          const SizedBox(height: 8),
          for (final option in options)
            _OptionRow(
              label: option.label,
              description: option.description,
              recommended: option.recommended,
            ),
          const SizedBox(height: 18),
          const MicroLabel('YOUR RATIONALE'),
          const SizedBox(height: 8),
          TextAreaBox(
            hintText:
                'Record why you are making this call. It is stored with the '
                'decision.',
            onChanged: (v) => setState(() => _rationale = v),
          ),
          if (widget.requiresWorkInFlightAssertion) ...[
            const SizedBox(height: 18),
            const ContentRule(),
            const SizedBox(height: 14),
            _WorkInFlightAssertion(
              checked: _attestsNoWorkInFlight,
              enabled: !widget.isResolving,
              onChanged: (v) => setState(() => _attestsNoWorkInFlight = v),
            ),
          ],
          const SizedBox(height: 16),
          const MicroLabel('OUTCOME'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final option in options)
                _ChoiceLink(
                  label: option.label,
                  selected: _choice == option.optionId,
                  onTap: widget.isResolving
                      ? null
                      : () => setState(() => _choice = option.optionId),
                ),
            ],
          ),
          if (!_canSubmit && !widget.isResolving)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.requiresWorkInFlightAssertion &&
                        _choice != null &&
                        _rationale.trim().isNotEmpty
                    ? 'Confirm that no work is running before this can be '
                          'recorded.'
                    : 'Choose an outcome and record a rationale to continue.',
                style: ShipItType.bodySmall.copyWith(
                  color: palette.inkTertiary,
                ),
              ),
            ),
          const SizedBox(height: 10),
          _GateSubmit(
            label: widget.isResolving
                ? 'Recording your decision…'
                : 'Record decision',
            enabled: _canSubmit,
            onTap: () => widget.onResolve(
              // `proceed` performs the transition; `decline` records the
              // decision and changes nothing. Both map onto a wire
              // `HumanDecisionChoice`.
              _choice == 'decline' ? 'reject' : 'approve',
              _rationale.trim(),
              _attestsNoWorkInFlight,
            ),
          ),
        ],
      ),
    );
  }
}

/// One server-declared outcome and what it does. The labels and wording come
/// from the decision itself, so the screen cannot describe an outcome the
/// engine did not offer.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.description,
    required this.recommended,
  });

  final String label;
  final String? description;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recommended ? '$label · recommended' : label,
            style: ShipItType.rowTitle.copyWith(color: palette.inkPrimary),
          ),
          if (description != null && description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                description!,
                style: ShipItType.bodySmall.copyWith(
                  color: palette.inkSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The operator's own statement that nothing is running for this product.
///
/// It is a statement, not a reading: the engine is handed this guard and trusts
/// it, so the copy says exactly that rather than implying the platform checked.
class _WorkInFlightAssertion extends StatelessWidget {
  const _WorkInFlightAssertion({
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: checked,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? () => onChanged(!checked) : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CustomPaint(
                    painter: _ChoiceDotPainter(
                      selected: checked,
                      enabled: enabled,
                      color: palette.accent,
                      idle: palette.inkTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No work is currently running for this product. You are '
                  'stating this; the registry records your statement and does '
                  'not check it.',
                  style: ShipItType.bodySmall.copyWith(
                    color: enabled ? palette.inkSecondary : palette.inkTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
              Flexible(
                child: Text(
                  'A baseline needs your approval',
                  style: ShipItType.sectionTitle.copyWith(
                    color: palette.inkPrimary,
                  ),
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
                // `rework`, not the phrase "request_correction":
                // `HumanDecisionChoice.fromWire` has no such value and throws,
                // which made this button a guaranteed 500. `rework` is what the
                // engine maps onto its `request_baseline_correction` option.
                selected: _choice == 'rework',
                onTap: widget.isResolving
                    ? null
                    : () => setState(() => _choice = 'rework'),
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
          // The engine refuses to open a baseline-approval gate on a candidate
          // no worker has independently verified, so the action is offered only
          // when one has.
          hasVerifiedPendingBaseline:
              detail.pendingBaselineId != null &&
              detail.pendingBaselineVerified,
        );
        // One gate at a time, and now for a durable reason rather than a
        // session one: while a lifecycle gate is open the action list is
        // hidden, because raising a second one would leave the first
        // unresolvable. Each lifecycle action raises its own `blocking: true`
        // gate and the registry will happily accept a second one — resolving
        // it can archive the product, after which the first can no longer be
        // raised (`archived -> paused` is not an edge), listed or resolved by
        // anything. `gateOpen` comes from the durable read, so this protection
        // survives leaving the route instead of lapsing with the page.
        final gateOpen = state.lifecycleGateOpen;
        final isBusy = state.isRaisingGate || state.isResolvingLifecycle;
        final panel = _GovernancePanel(
          detail: detail,
          status: status,
          livePolicies: live,
          actions: gateOpen ? const [] : actions,
          governanceError: state.governanceError,
          isBusy: isBusy,
          gateOpen: gateOpen,
          onGovernance: (action) => context.read<ProductDetailBloc>().add(
            GovernanceActionRequested(action, detail.productId),
          ),
        );

        if (isMobile(context)) {
          return _MobileDetail(
            detail: detail,
            status: status,
            live: live,
            panel: panel,
            lifecycleGate: _lifecycleGate(context, state),
            baselineGate: _baselineGate(context, state),
          );
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
                  _baselineGate(context, state)!,
                  const SizedBox(height: 22),
                ],
                if (state.lifecycleGateOpen) ...[
                  _lifecycleGate(context, state)!,
                  const SizedBox(height: 22),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _LeftColumn(detail: detail, status: status),
                    ),
                    const SizedBox(width: ShipItMetrics.sidePanelGap),
                    SizedBox(width: ShipItMetrics.sidePanelWidth, child: panel),
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

  /// The lifecycle gate this product has open, rendered in place. Null when none
  /// is open.
  ///
  /// Driven by durable state rather than by the response of the call that
  /// raised it — the same discipline as [_baselineGate], and for the same
  /// reason: this gate must still be here, resolvable, after the operator has
  /// navigated away and come back.
  Widget? _lifecycleGate(BuildContext context, ProductDetailState state) {
    final gate = state.openLifecycleGate;
    if (gate == null) return null;
    return _LifecycleDecisionGate(
      gate: gate,
      requiresWorkInFlightAssertion:
          state.lifecycleOffboardNeedsWorkInFlightAssertion,
      isResolving: state.isResolvingLifecycle,
      onResolve: (choice, rationale, noWorkInFlight) =>
          context.read<ProductDetailBloc>().add(
            LifecycleDecisionResolved(
              // The product is the one on screen. Parsing the synthetic
              // `product-lifecycle:<id>` scope back out of the decision would
              // be guessing at a string format for no gain.
              productId: state.detail!.productId,
              decisionId: gate.decisionId,
              choice: choice,
              rationale: rationale,
              attestsNoWorkInFlight: noWorkInFlight,
            ),
          ),
    );
  }

  /// The baseline-approval gate, driven by durable state rather than by the
  /// response of the call that raised it.
  Widget? _baselineGate(BuildContext context, ProductDetailState state) {
    final detail = state.detail;
    if (detail == null || !state.canApproveBaseline) return null;
    return _BaselineApprovalGate(
      detail: detail,
      isResolving: state.isResolvingBaseline,
      onResolve: (choice, rationale) => context.read<ProductDetailBloc>().add(
        BaselineApprovalResolved(
          productId: detail.productId,
          choice: choice,
          rationale: rationale,
        ),
      ),
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

/// The Governance panel: what is true about governance, what the operator may
/// do about it, and — when something is refused — what the refusal said.
///
/// Stateful because the one interaction that needs to survive a rebuild is the
/// typed confirmation for offboarding a governed product.
class _GovernancePanel extends StatefulWidget {
  const _GovernancePanel({
    required this.detail,
    required this.status,
    required this.livePolicies,
    required this.actions,
    required this.governanceError,
    required this.isBusy,
    required this.gateOpen,
    required this.onGovernance,
  });

  final ProductDetailResponse detail;
  final ProductStatus status;
  final List<PolicyResponse> livePolicies;
  final List<GovernanceAction> actions;

  /// An action-scoped failure. Rendered here, beside the actions that caused
  /// it, rather than taking the whole page over.
  final String? governanceError;

  /// True while an action's server call is in flight.
  final bool isBusy;

  /// True while a lifecycle gate raised from this screen is still open. The
  /// action list is hidden then, so a second gate cannot be stranded.
  final bool gateOpen;

  /// Dispatches the action back to the bloc. The panel never performs the
  /// durable write itself.
  final ValueChanged<GovernanceAction> onGovernance;

  @override
  State<_GovernancePanel> createState() => _GovernancePanelState();
}

class _GovernancePanelState extends State<_GovernancePanel> {
  /// The action awaiting typed confirmation, or null.
  GovernanceAction? _confirming;

  /// What the operator has typed so far for that confirmation.
  String _typed = '';

  @override
  void didUpdateWidget(_GovernancePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A gate opening, or the product moving on, invalidates a half-typed
    // confirmation: the thing being confirmed is no longer on screen.
    if (widget.gateOpen != oldWidget.gateOpen ||
        widget.status != oldWidget.status) {
      _confirming = null;
      _typed = '';
    }
  }

  /// Offboarding a governed product discards an accepted baseline and cannot be
  /// reversed without a fresh baseline review, so it is fenced behind typing
  /// the product id (Human Decision f9a043ae, 2026-10-09). A product that never
  /// governed has nothing to lose and offboards in one tap.
  bool _needsTypedConfirmation(GovernanceAction action) =>
      action == GovernanceAction.offboard &&
      (widget.status == ProductStatus.governed ||
          widget.status == ProductStatus.paused);

  void _request(GovernanceAction action) {
    if (_needsTypedConfirmation(action)) {
      setState(() {
        _confirming = action;
        _typed = '';
      });
      return;
    }
    widget.onGovernance(action);
  }

  void _cancelConfirmation() => setState(() {
    _confirming = null;
    _typed = '';
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final policy = widget.livePolicies.firstOrNull;
    final credential = widget.detail.credentials.firstOrNull;
    final busy = widget.isBusy;
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
            _panelSub(widget.status),
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 18),
          const ContentRule(),
          const SizedBox(height: 16),
          _PanelEntry(
            label: 'ACTIVE BASELINE',
            value: widget.detail.activeBaselineId == null
                ? 'None accepted'
                : '${widget.detail.activeBaselineId} · accepted'
                      '${widget.detail.activeBaselineAcceptedBy == null ? '' : ' by ${widget.detail.activeBaselineAcceptedBy}'}',
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
                ? widget.status == ProductStatus.governed
                      ? 'None — every push waits for you'
                      : 'None — available once this product is governed'
                : '${policy.actions.join(" and ")} · authorised by '
                      '${policy.authorisedBy} · ref '
                      '${policy.authorisingDecisionId}',
          ),
          if (widget.governanceError != null) ...[
            const SizedBox(height: 20),
            _GovernanceError(
              reason: widget.governanceError!,
              onDismiss: () => context.read<ProductDetailBloc>().add(
                const GovernanceErrorDismissed(),
              ),
            ),
          ],
          if (widget.gateOpen) ...[
            const SizedBox(height: 20),
            const ContentRule(),
            const SizedBox(height: 14),
            Text(
              'A lifecycle decision is open above. Record it there before '
              'raising another.',
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            ),
          ] else if (widget.actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const ContentRule(),
            const SizedBox(height: 14),
            for (final action in widget.actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GovernanceAction(
                  label: action.label,
                  enabled: !busy && _confirming == null,
                  onTap: () => _request(action),
                ),
              ),
            if (_confirming != null) ...[
              const SizedBox(height: 4),
              _TypedConfirmation(
                productId: widget.detail.productId,
                typed: _typed,
                busy: busy,
                onChanged: (v) => setState(() => _typed = v),
                onCancel: _cancelConfirmation,
                onConfirm: () => widget.onGovernance(_confirming!),
              ),
            ],
            if (busy)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Working…',
                    style: ShipItType.monoMeta.copyWith(
                      color: palette.inkTertiary,
                    ),
                  ),
                ),
              ),
          ],
          if (widget.status == ProductStatus.archived) ...[
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

/// A governance action.
///
/// A real button, not a link on a gesture detector: `InlineLink` is
/// `Semantics(link: true)` over a `GestureDetector`, which has no focusable
/// node, no `button` role and no disabled state — so a screen-reader or
/// keyboard operator could not reach these actions at all, and nothing
/// announced that one was in flight. The pixels are unchanged; the semantics
/// are not.
class _GovernanceAction extends StatelessWidget {
  const _GovernanceAction({
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
    return Semantics(
      button: true,
      enabled: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: ShipItType.link.copyWith(
                  color: enabled ? palette.accent : palette.inkTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The typed confirmation for an irreversible offboard.
///
/// Nothing is sent until the typed text is exactly the product id. The
/// consequence is stated before the box, because a mistaken tap on an archive
/// cannot be undone by retyping.
class _TypedConfirmation extends StatelessWidget {
  const _TypedConfirmation({
    required this.productId,
    required this.typed,
    required this.busy,
    required this.onChanged,
    required this.onCancel,
    required this.onConfirm,
  });

  final String productId;
  final String typed;
  final bool busy;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final matches = typed.trim() == productId;
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Offboarding archives this product. It stops dispatching, it leaves '
            'the All products list, and it stays readable under Archived — '
            'nothing is deleted.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 10),
          DesignTextField(
            label: 'TYPE $productId TO CONFIRM',
            hintText: productId,
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          // A `Wrap`, not a `Row`: the panel is 360px wide on desktop and the
          // two controls do not both fit across it.
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _GateSubmit(
                label: busy ? 'Working…' : 'Confirm offboard',
                enabled: matches && !busy,
                onTap: onConfirm,
              ),
              _ChoiceLink(
                label: 'Cancel',
                selected: false,
                onTap: busy ? null : onCancel,
              ),
            ],
          ),
          if (!matches && typed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'That is not the product id. Nothing has been sent.',
                style: ShipItType.bodySmall.copyWith(color: palette.negative),
              ),
            ),
        ],
      ),
    );
  }
}

/// An action-scoped failure, beside the actions that produced it.
///
/// It is deliberately not `DesignErrorState`: that copy leads with "No decision
/// was recorded and no work was started", which is the opposite of what a
/// refusal means, and taking the page over would throw away the product the
/// operator was looking at. `liveRegion` because it appears next to a control
/// the operator just pressed and may never be looking at.
class _GovernanceError extends StatelessWidget {
  const _GovernanceError({required this.reason, required this.onDismiss});

  /// The server's own reason, verbatim.
  final String reason;

  /// Clears the panel. It does not re-run the action: the operator chose to
  /// dismiss a refusal, not to press the button a second time.
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      liveRegion: true,
      child: DesignPanel(
        edgeColor: palette.negative,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The registry refused that action.',
              style: ShipItType.rowTitle.copyWith(color: palette.negative),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Nothing has been changed. No decision was recorded and no work '
              'was started or stopped by this.',
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
            const SizedBox(height: 8),
            _ChoiceLink(label: 'Dismiss', selected: false, onTap: onDismiss),
          ],
        ),
      ),
    );
  }
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
    required this.panel,
    required this.lifecycleGate,
    required this.baselineGate,
  });

  final ProductDetailResponse detail;
  final ProductStatus status;
  final List<PolicyResponse> live;

  /// The Governance panel, built by the caller so the desktop and mobile
  /// compositions read exactly the same durable state. Rendering it here
  /// instead used to mean calling `availableFor` twice, which is how the two
  /// layouts could drift apart on what the engine would accept.
  final Widget panel;

  /// The in-place lifecycle gate, or null when none is open. Present on mobile
  /// for the same reason it is present on desktop: a gate raised here must be
  /// resolvable here, or the mobile layout produces write-only decisions.
  final Widget? lifecycleGate;

  /// The in-place baseline-approval gate, or null when none is open.
  final Widget? baselineGate;

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
                  if (baselineGate != null) ...[
                    const SizedBox(height: 22),
                    baselineGate!,
                  ],
                  if (lifecycleGate != null) ...[
                    const SizedBox(height: 22),
                    lifecycleGate!,
                  ],
                  const SizedBox(height: 22),
                  panel,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
