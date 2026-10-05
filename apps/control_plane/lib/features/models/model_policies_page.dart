import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/design_primitives.dart';
import '../../shared/mobile_chrome.dart';
import '../../shared/state_views.dart';
import 'model_policies_bloc.dart';

class ModelPoliciesPage extends StatelessWidget {
  const ModelPoliciesPage({super.key, this.bloc});

  final ModelPoliciesBloc? bloc;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<ModelPoliciesBloc>.value(
            value: provided,
            child: const _ModelPoliciesView(),
          )
        : BlocProvider<ModelPoliciesBloc>(
            create: (_) =>
                ModelPoliciesBloc(repository: ClientProvider.repository)
                  ..add(const ModelPoliciesLoaded()),
            child: const _ModelPoliciesView(),
          );
  }
}

class _ModelPoliciesView extends StatefulWidget {
  const _ModelPoliciesView();

  @override
  State<_ModelPoliciesView> createState() => _ModelPoliciesViewState();
}

class _ModelPoliciesViewState extends State<_ModelPoliciesView> {
  ModelPolicyRow? _editingPolicy;
  final List<ModelStepEditor> _stepEditors = [];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModelPoliciesBloc, ModelPoliciesState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const DesignLoadingSkeleton(
            title: 'Model Policies',
            showColumns: true,
          );
        }
        if (state.errorMessage != null) {
          return DesignErrorState(
            title: "We could not reach the system's records.",
            detail: state.errorMessage!,
            onRetry: () => context.read<ModelPoliciesBloc>().add(
              const ModelPoliciesLoaded(),
            ),
          );
        }

        if (isMobile(context)) {
          return _MobileModelPolicies(
            policies: state.policies,
            knownModels: state.knownModels,
            providerHealth: state.safeProviderHealth,
            editingPolicy: _editingPolicy,
            stepEditors: _stepEditors,
            onEdit: _startEditing,
            onSave: _savePolicy,
            onCancel: _cancelEditing,
            onAddStep: _addStep,
            onRemoveStep: _removeStep,
            onReorderStep: _reorderStep,
            onStepChanged: _onStepChanged,
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ShipItMetrics.contentGutter,
              30,
              ShipItMetrics.contentGutter,
              23,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Model Policies',
                  subtitle: _buildSubtitle(state.policies),
                  liveLabel: 'LIVE',
                ),
                const SizedBox(height: 25),
                if (_editingPolicy != null) ...[
                  _PolicyEditorPanel(
                    policy: _editingPolicy!,
                    stepEditors: _stepEditors,
                    knownModels: state.knownModels,
                    providerHealth: state.safeProviderHealth,
                    onSave: _savePolicy,
                    onCancel: _cancelEditing,
                    onAddStep: _addStep,
                    onRemoveStep: _removeStep,
                    onReorderStep: _reorderStep,
                    onStepChanged: _onStepChanged,
                  ),
                  const SizedBox(height: 24),
                ],
                _PolicyTable(
                  policies: state.policies,
                  knownModels: state.knownModels,
                  editingPolicy: _editingPolicy,
                  onEdit: _startEditing,
                ),
                const SizedBox(height: 46),
                TechnicalDetails(
                  note:
                      'Model policies are durable records. Changes require a human decision citation.',
                  lines: [
                    'policies=${state.policies.length}',
                    for (final p in state.policies)
                      '${p.role} v${p.version} · chain=${p.chain.length} · active=${p.isActive} · updatedBy=${p.updatedByDecisionId}',
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildSubtitle(List<ModelPolicyRow> policies) {
    final active = policies.where((p) => p.isActive).length;
    return '$active active of ${policies.length} roles configured';
  }

  void _startEditing(ModelPolicyRow policy) {
    final editors = policy.chain
        .map((s) => ModelStepEditor(modelId: s.modelId, provider: s.provider))
        .toList();
    setState(() {
      _editingPolicy = policy;
      _stepEditors.clear();
      _stepEditors.addAll(editors);
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingPolicy = null;
      _stepEditors.clear();
    });
  }

  void _addStep() {
    setState(() {
      _stepEditors.add(ModelStepEditor());
    });
  }

  void _removeStep(int index) {
    setState(() {
      _stepEditors.removeAt(index);
    });
  }

  void _reorderStep(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex--;
      final item = _stepEditors.removeAt(oldIndex);
      _stepEditors.insert(newIndex, item);
    });
  }

  void _onStepChanged(int index, ModelStepEditor editor) {
    setState(() {
      _stepEditors[index] = editor;
    });
  }

  Future<void> _savePolicy() async {
    if (_editingPolicy == null) return;

    final chain = _stepEditors
        .where((e) => e.modelId.isNotEmpty && e.provider.isNotEmpty)
        .map((e) => ModelStepRequest(modelId: e.modelId, provider: e.provider))
        .toList();

    if (chain.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one step is required')),
      );
      return;
    }

    try {
      await context.read<ModelPoliciesBloc>().repository.updateModelPolicy(
        role: _editingPolicy!.role,
        chain: chain,
        version: _editingPolicy!.version + 1,
        updatedByDecisionId: 'manual-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        context.read<ModelPoliciesBloc>().add(const ModelPoliciesLoaded());
        _cancelEditing();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Policy updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }
}

class _PolicyTable extends StatelessWidget {
  const _PolicyTable({
    required this.policies,
    required this.knownModels,
    this.editingPolicy,
    required this.onEdit,
  });

  final List<ModelPolicyRow> policies;
  final List<KnownModelResponse> knownModels;
  final ModelPolicyRow? editingPolicy;
  final ValueChanged<ModelPolicyRow> onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 7),
          child: Row(
            children: [
              SizedBox(width: ShipItMetrics.colWhat, child: MicroLabel('ROLE')),
              Expanded(child: MicroLabel('MODEL CHAIN')),
              SizedBox(width: 120, child: MicroLabel('VERSION')),
              SizedBox(width: 180, child: MicroLabel('UPDATED')),
              SizedBox(width: 160, child: MicroLabel('UPDATED BY')),
              SizedBox(width: 80, child: MicroLabel('STATUS')),
              SizedBox(width: 140),
            ],
          ),
        ),
        const ContentRule(strong: true),
        if (policies.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No model policies configured.',
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            ),
          )
        else
          for (final policy in policies)
            _PolicyTableRow(
              policy: policy,
              onEdit: onEdit,
              isEditing: editingPolicy?.role == policy.role,
            ),
      ],
    );
  }
}

class _PolicyTableRow extends StatelessWidget {
  const _PolicyTableRow({
    required this.policy,
    required this.onEdit,
    this.isEditing = false,
  });

  final ModelPolicyRow policy;
  final ValueChanged<ModelPolicyRow> onEdit;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final activeColor = policy.isActive
        ? palette.positive
        : palette.inkTertiary;
    return Column(
      children: [
        SizedBox(
          height: ShipItMetrics.rowPitch - ShipItMetrics.hairline,
          child: Row(
            children: [
              SizedBox(
                width: ShipItMetrics.colWhat,
                child: Row(
                  children: [
                    AccentTick(
                      color: policy.isActive
                          ? palette.positive
                          : palette.inkTertiary,
                      height: ShipItMetrics.rowTickHeight,
                    ),
                    const SizedBox(width: ShipItMetrics.colRefInset - 2),
                    Expanded(
                      child: Text(
                        policy.roleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShipItType.ref.copyWith(
                          color: palette.inkPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < policy.chain.length; i++) ...[
                      if (i > 0) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: palette.inkTertiary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      _ModelBadge(
                        modelId: policy.chain[i].modelId,
                        provider: policy.chain[i].provider,
                        isActive: i == 0,
                      ),
                    ],
                    if (policy.chain.isEmpty)
                      Text(
                        '(no steps)',
                        style: ShipItType.monoMeta.copyWith(
                          color: palette.inkTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  'v${policy.version}',
                  style: ShipItType.status.copyWith(
                    color: palette.inkSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: Text(
                  _formatDate(policy.updatedAt),
                  style: ShipItType.status.copyWith(color: palette.inkTertiary),
                ),
              ),
              SizedBox(
                width: 160,
                child: Text(
                  policy.updatedByDecisionId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShipItType.monoMeta.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      policy.isActive ? 'Active' : 'Inactive',
                      style: ShipItType.status.copyWith(color: activeColor),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 140,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: isEditing
                      ? InlineLink(label: 'Cancel', onTap: () => onEdit(policy))
                      : InlineLink(label: 'Edit', onTap: () => onEdit(policy)),
                ),
              ),
            ],
          ),
        ),
        const ContentRule(),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ModelBadge extends StatelessWidget {
  const _ModelBadge({
    required this.modelId,
    required this.provider,
    this.isActive = false,
  });

  final String modelId;
  final String provider;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? palette.positive.withValues(alpha: 0.1)
            : palette.card,
        border: Border.all(
          color: isActive
              ? palette.positive.withValues(alpha: 0.5)
              : palette.cardBorder,
          width: ShipItMetrics.hairline,
        ),
        borderRadius: BorderRadius.circular(ShipItMetrics.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: palette.positive,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            modelId,
            style: ShipItType.monoMeta.copyWith(
              color: isActive ? palette.positive : palette.inkSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            provider,
            style: ShipItType.monoMeta.copyWith(
              color: palette.inkTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyEditorPanel extends StatelessWidget {
  const _PolicyEditorPanel({
    required this.policy,
    required this.stepEditors,
    required this.knownModels,
    required this.providerHealth,
    required this.onSave,
    required this.onCancel,
    required this.onAddStep,
    required this.onRemoveStep,
    required this.onReorderStep,
    required this.onStepChanged,
  });

  final ModelPolicyRow policy;
  final List<ModelStepEditor> stepEditors;
  final List<KnownModelResponse> knownModels;
  final ProviderHealthResponse providerHealth;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onAddStep;
  final ValueChanged<int> onRemoveStep;
  final Function(int, int) onReorderStep;
  final Function(int, ModelStepEditor) onStepChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      edgeColor: palette.accentTick,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Editing ${policy.roleLabel} (v${policy.version} → v${policy.version + 1})',
                style: ShipItType.sectionTitle.copyWith(
                  color: palette.inkPrimary,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(onPressed: onSave, child: const Text('Save Policy')),
            ],
          ),
          const SizedBox(height: 16),
          const ContentRule(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MicroLabel('MODEL CHAIN (DRAG TO REORDER)'),
                    const SizedBox(height: 8),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stepEditors.length,
                      onReorderItem: (int oldIndex, int newIndex) =>
                          onReorderStep(oldIndex, newIndex),
                      buildDefaultDragHandles: true,
                      itemBuilder: (context, index) {
                        final editor = stepEditors[index];
                        return _StepEditorRow(
                          key: ValueKey(index),
                          index: index,
                          editor: editor,
                          knownModels: knownModels,
                          providerHealth: providerHealth,
                          onChanged: (newEditor) =>
                              onStepChanged(index, newEditor),
                          onRemove: () => onRemoveStep(index),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MicroLabel('ESCALATION PATH PREVIEW'),
                    const SizedBox(height: 8),
                    _EscalationPreview(
                      chain: stepEditors
                          .where(
                            (e) =>
                                e.modelId.isNotEmpty && e.provider.isNotEmpty,
                          )
                          .map(
                            (e) => ModelStepResponse(
                              modelId: e.modelId,
                              provider: e.provider,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onAddStep,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Step'),
              ),
              const Spacer(),
              Text(
                '${stepEditors.where((e) => e.modelId.isNotEmpty).length} step(s) configured',
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepEditorRow extends StatelessWidget {
  const _StepEditorRow({
    super.key,
    required this.index,
    required this.editor,
    required this.knownModels,
    required this.providerHealth,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final ModelStepEditor editor;
  final List<KnownModelResponse> knownModels;
  final ProviderHealthResponse providerHealth;
  final ValueChanged<ModelStepEditor> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final providers = providerHealth.providers.map((p) => p.provider).toList();
    final modelsForProvider = editor.provider.isNotEmpty
        ? knownModels.where((m) => m.provider == editor.provider).toList()
        : knownModels;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Step ${index + 1}',
                  style: ShipItType.ref.copyWith(color: palette.inkPrimary),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Remove step',
                  style: IconButton.styleFrom(
                    foregroundColor: palette.negative,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownMenu<String>(
                    initialSelection: editor.provider.isEmpty
                        ? null
                        : editor.provider,
                    label: const Text('Provider'),
                    dropdownMenuEntries: providers
                        .map((p) => DropdownMenuEntry(value: p, label: p))
                        .toList(),
                    onSelected: (value) {
                      if (value != null) {
                        onChanged(
                          editor.copyWith(provider: value, modelId: ''),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownMenu<String>(
                    initialSelection: editor.modelId.isEmpty
                        ? null
                        : editor.modelId,
                    label: const Text('Model'),
                    dropdownMenuEntries: modelsForProvider
                        .map(
                          (m) => DropdownMenuEntry(
                            value: m.modelId,
                            label: m.displayName ?? m.modelId,
                          ),
                        )
                        .toList(),
                    onSelected: (value) {
                      if (value != null) {
                        onChanged(editor.copyWith(modelId: value));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: index == 0 ? palette.positive : palette.inkTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  index == 0
                      ? 'Currently active model'
                      : 'Escalation step ${index}',
                  style: ShipItType.monoMeta.copyWith(
                    color: index == 0 ? palette.positive : palette.inkTertiary,
                  ),
                ),
              ],
            ),
            const ContentRule(),
          ],
        ),
      ),
    );
  }
}

class _EscalationPreview extends StatelessWidget {
  const _EscalationPreview({required this.chain});

  final List<ModelStepResponse> chain;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (chain.isEmpty) {
      return Text(
        'No steps configured',
        style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < chain.length; i++) ...[
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == 0 ? palette.positive : palette.inkTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i == 0 ? 'Primary' : 'Escalation ${i}',
                      style: ShipItType.ref.copyWith(
                        color: i == 0 ? palette.positive : palette.inkSecondary,
                        fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    Text(
                      '${chain[i].modelId} (${chain[i].provider})',
                      style: ShipItType.monoMeta.copyWith(
                        color: palette.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (i < chain.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MobileModelPolicies extends StatelessWidget {
  const _MobileModelPolicies({
    required this.policies,
    required this.knownModels,
    required this.providerHealth,
    required this.editingPolicy,
    required this.stepEditors,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
    required this.onAddStep,
    required this.onRemoveStep,
    required this.onReorderStep,
    required this.onStepChanged,
  });

  final List<ModelPolicyRow> policies;
  final List<KnownModelResponse> knownModels;
  final ProviderHealthResponse providerHealth;
  final ModelPolicyRow? editingPolicy;
  final List<ModelStepEditor> stepEditors;
  final ValueChanged<ModelPolicyRow> onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onAddStep;
  final ValueChanged<int> onRemoveStep;
  final Function(int, int) onReorderStep;
  final Function(int, ModelStepEditor) onStepChanged;

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
              'Model Policies',
              style: ShipItType.pageTitle.copyWith(color: palette.inkPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              '${policies.where((p) => p.isActive).length} active of ${policies.length} roles',
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
            const SizedBox(height: 18),
            const ContentRule(strong: true),
            if (editingPolicy != null) ...[
              _MobilePolicyEditor(
                policy: editingPolicy!,
                stepEditors: stepEditors,
                knownModels: knownModels,
                providerHealth: providerHealth,
                onSave: onSave,
                onCancel: onCancel,
                onAddStep: onAddStep,
                onRemoveStep: onRemoveStep,
                onReorderStep: onReorderStep,
                onStepChanged: onStepChanged,
              ),
              const SizedBox(height: 16),
              const ContentRule(),
              const SizedBox(height: 16),
            ],
            if (policies.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No model policies configured.',
                  style: ShipItType.bodySmall.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              )
            else
              for (final policy in policies)
                _MobilePolicyCard(
                  policy: policy,
                  onEdit: onEdit,
                  isEditing: editingPolicy?.role == policy.role,
                ),
          ],
        ),
      ),
    );
  }
}

class _MobilePolicyCard extends StatelessWidget {
  const _MobilePolicyCard({
    required this.policy,
    required this.onEdit,
    this.isEditing = false,
  });

  final ModelPolicyRow policy;
  final ValueChanged<ModelPolicyRow> onEdit;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final innerColumn = _buildInnerColumn(context, palette);

    return Column(
      children: [
        InkWell(
          onTap: () => onEdit(policy),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: innerColumn,
          ),
        ),
        const ContentRule(),
      ],
    );
  }

  Widget _buildInnerColumn(BuildContext context, ShipItPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AccentTick(
              color: policy.isActive ? palette.positive : palette.inkTertiary,
              height: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        policy.roleLabel,
                        style: ShipItType.rowTitle.copyWith(
                          color: palette.inkPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (policy.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.positive.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: ShipItType.microLabel.copyWith(
                              color: palette.positive,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < policy.chain.length; i++)
                        _ModelBadge(
                          modelId: policy.chain[i].modelId,
                          provider: policy.chain[i].provider,
                          isActive: i == 0,
                        ),
                      if (policy.chain.isEmpty)
                        Text(
                          '(no steps)',
                          style: ShipItType.monoMeta.copyWith(
                            color: palette.inkTertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v${policy.version} · ${_formatDate(policy.updatedAt)} · by ${policy.updatedByDecisionId}',
                    style: ShipItType.monoMeta.copyWith(
                      color: palette.inkTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _MobilePolicyEditor extends StatelessWidget {
  const _MobilePolicyEditor({
    required this.policy,
    required this.stepEditors,
    required this.knownModels,
    required this.providerHealth,
    required this.onSave,
    required this.onCancel,
    required this.onAddStep,
    required this.onRemoveStep,
    required this.onReorderStep,
    required this.onStepChanged,
  });

  final ModelPolicyRow policy;
  final List<ModelStepEditor> stepEditors;
  final List<KnownModelResponse> knownModels;
  final ProviderHealthResponse providerHealth;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onAddStep;
  final ValueChanged<int> onRemoveStep;
  final Function(int, int) onReorderStep;
  final Function(int, ModelStepEditor) onStepChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Editing ${policy.roleLabel}',
              style: ShipItType.sectionTitle.copyWith(
                color: palette.inkPrimary,
              ),
            ),
            const Spacer(),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(onPressed: onSave, child: const Text('Save')),
          ],
        ),
        const SizedBox(height: 16),
        const MicroLabel('MODEL CHAIN'),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stepEditors.length,
          onReorderItem: (int oldIndex, int newIndex) =>
              onReorderStep(oldIndex, newIndex),
          buildDefaultDragHandles: true,
          itemBuilder: (context, index) {
            final editor = stepEditors[index];
            return _StepEditorRow(
              key: ValueKey(index),
              index: index,
              editor: editor,
              knownModels: knownModels,
              providerHealth: providerHealth,
              onChanged: (newEditor) => onStepChanged(index, newEditor),
              onRemove: () => onRemoveStep(index),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onAddStep,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Step'),
            ),
            const Spacer(),
            Text(
              '${stepEditors.where((e) => e.modelId.isNotEmpty).length} step(s)',
              style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const MicroLabel('ESCALATION PATH'),
        const SizedBox(height: 8),
        _EscalationPreview(
          chain: stepEditors
              .where((e) => e.modelId.isNotEmpty && e.provider.isNotEmpty)
              .map(
                (e) =>
                    ModelStepResponse(modelId: e.modelId, provider: e.provider),
              )
              .toList(),
        ),
      ],
    );
  }
}

class ModelStepEditor {
  const ModelStepEditor({this.modelId = '', this.provider = ''});

  final String modelId;
  final String provider;

  ModelStepEditor copyWith({String? modelId, String? provider}) {
    return ModelStepEditor(
      modelId: modelId ?? this.modelId,
      provider: provider ?? this.provider,
    );
  }
}
