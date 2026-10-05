import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/design_primitives.dart';
import '../../shared/form_primitives.dart';
import '../../shared/mobile_chrome.dart'
    show isMobile;
import '../../shared/state_views.dart';
import 'model_executions_bloc.dart';

class ModelExecutionsPage extends StatelessWidget {
  const ModelExecutionsPage({super.key, this.bloc});

  final ModelExecutionsBloc? bloc;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<ModelExecutionsBloc>.value(
            value: provided,
            child: const _ModelExecutionsView(),
          )
        : BlocProvider<ModelExecutionsBloc>(
            create: (_) =>
                ModelExecutionsBloc(repository: ClientProvider.repository)
                  ..add(const ModelExecutionsLoaded()),
            child: const _ModelExecutionsView(),
          );
  }
}

class _ModelExecutionsView extends StatefulWidget {
  const _ModelExecutionsView();

  @override
  State<_ModelExecutionsView> createState() => _ModelExecutionsViewState();
}

class _ModelExecutionsViewState extends State<_ModelExecutionsView> {
  final _workItemIdController = TextEditingController();
  final _providerController = TextEditingController();
  final _modelIdController = TextEditingController();
  String? _taskTypeFilter;
  bool? _successFilter;
  DateTimeRange? _dateRange;
  int _page = 0;
  static const _pageSize = 50;

  @override
  void dispose() {
    _workItemIdController.dispose();
    _providerController.dispose();
    _modelIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModelExecutionsBloc, ModelExecutionsState>(
      builder: (context, state) {
        if (state.isLoading && state.executions.isEmpty) {
          return const DesignLoadingSkeleton(
            title: 'Model Executions',
            showColumns: true,
          );
        }
        if (state.errorMessage != null && state.executions.isEmpty) {
          return DesignErrorState(
            title: "We could not reach the system's records.",
            detail: state.errorMessage!,
            onRetry: () =>
                context.read<ModelExecutionsBloc>().add(const ModelExecutionsLoaded()),
          );
        }

        final rows = state.executions;

        if (isMobile(context)) {
          return _MobileModelExecutions(
            rows: rows,
            totalCount: state.totalCount,
            page: _page,
            pageSize: _pageSize,
            onPageChanged: _onPageChanged,
            filters: _Filters(
              workItemId: _workItemIdController.text,
              provider: _providerController.text,
              modelId: _modelIdController.text,
              taskType: _taskTypeFilter,
              success: _successFilter,
              dateRange: _dateRange,
            ),
            onFilterChanged: _onFilterChanged,
            onClearFilters: _clearFilters,
            taskTypes: state.taskTypes,
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
                  title: 'Model Executions',
                  subtitle: '${rows.length} of ${state.totalCount} executions',
                  liveLabel: 'LIVE',
                ),
                const SizedBox(height: 25),
                _FilterPanel(
                  workItemIdController: _workItemIdController,
                  providerController: _providerController,
                  modelIdController: _modelIdController,
                  taskTypeFilter: _taskTypeFilter,
                  successFilter: _successFilter,
                  dateRange: _dateRange,
                  taskTypes: state.taskTypes,
                  onFilterChanged: _onFilterChanged,
                  onClearFilters: _clearFilters,
                  onDateRangeChanged: _onDateRangeChanged,
                ),
                const SizedBox(height: 24),
                Text(
                  '${rows.length} of ${state.totalCount} executions',
                  style: ShipItType.sectionTitle.copyWith(
                    color: context.palette.inkPrimary,
                  ),
                ),
                const SizedBox(height: 9),
                _ExecutionsTable(
                  rows: rows,
                  emptyMessage: 'No executions match the current filters.',
                ),
                const SizedBox(height: 16),
                _PaginationControls(
                  totalCount: state.totalCount,
                  page: _page,
                  pageSize: _pageSize,
                  onPageChanged: _onPageChanged,
                ),
                const SizedBox(height: 46),
                TechnicalDetails(
                  note: 'Executions are read from durable records. Costs are in USD.',
                  lines: [
                    'page=${_page + 1} · size=$_pageSize · total=${state.totalCount}',
                    'filters: wi=${_workItemIdController.text.isEmpty ? 'all' : _workItemIdController.text} '
                        'provider=${_providerController.text.isEmpty ? 'all' : _providerController.text} '
                        'model=${_modelIdController.text.isEmpty ? 'all' : _modelIdController.text} '
                        'taskType=${_taskTypeFilter ?? 'all'} '
                        'success=${_successFilter?.toString() ?? 'all'} '
                        'range=${_dateRange?.start.toIso8601String() ?? 'none'}..${_dateRange?.end.toIso8601String() ?? 'none'}',
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onFilterChanged(_Filters filters) {
    setState(() {
      _workItemIdController.text = filters.workItemId;
      _providerController.text = filters.provider;
      _modelIdController.text = filters.modelId;
      _taskTypeFilter = filters.taskType;
      _successFilter = filters.success;
      _dateRange = filters.dateRange;
      _page = 0;
    });
    context.read<ModelExecutionsBloc>().add(ModelExecutionsLoaded(
          workItemId: filters.workItemId.isEmpty ? null : filters.workItemId,
          provider: filters.provider.isEmpty ? null : filters.provider,
          modelId: filters.modelId.isEmpty ? null : filters.modelId,
          taskType: filters.taskType,
          success: filters.success,
          from: filters.dateRange?.start,
          to: filters.dateRange?.end,
          limit: _pageSize,
          offset: 0,
        ));
  }

  void _clearFilters() {
    setState(() {
      _workItemIdController.clear();
      _providerController.clear();
      _modelIdController.clear();
      _taskTypeFilter = null;
      _successFilter = null;
      _dateRange = null;
      _page = 0;
    });
    context.read<ModelExecutionsBloc>().add(const ModelExecutionsLoaded());
  }

  void _onDateRangeChanged(DateTimeRange? range) {
    setState(() {
      _dateRange = range;
      _page = 0;
    });
    _onFilterChanged(_Filters(
      workItemId: _workItemIdController.text,
      provider: _providerController.text,
      modelId: _modelIdController.text,
      taskType: _taskTypeFilter,
      success: _successFilter,
      dateRange: range,
    ));
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    context.read<ModelExecutionsBloc>().add(ModelExecutionsLoaded(
          workItemId: _workItemIdController.text.isEmpty ? null : _workItemIdController.text,
          provider: _providerController.text.isEmpty ? null : _providerController.text,
          modelId: _modelIdController.text.isEmpty ? null : _modelIdController.text,
          taskType: _taskTypeFilter,
          success: _successFilter,
          from: _dateRange?.start,
          to: _dateRange?.end,
          limit: _pageSize,
          offset: page * _pageSize,
        ));
  }
}

class _Filters {
  const _Filters({
    required this.workItemId,
    required this.provider,
    required this.modelId,
    this.taskType,
    this.success,
    this.dateRange,
  });

  final String workItemId;
  final String provider;
  final String modelId;
  final String? taskType;
  final bool? success;
  final DateTimeRange? dateRange;
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.workItemIdController,
    required this.providerController,
    required this.modelIdController,
    required this.taskTypeFilter,
    required this.successFilter,
    required this.dateRange,
    required this.taskTypes,
    required this.onFilterChanged,
    required this.onClearFilters,
    required this.onDateRangeChanged,
  });

  final TextEditingController workItemIdController;
  final TextEditingController providerController;
  final TextEditingController modelIdController;
  final String? taskTypeFilter;
  final bool? successFilter;
  final DateTimeRange? dateRange;
  final List<String> taskTypes;
  final ValueChanged<_Filters> onFilterChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Filters', style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary)),
              const Spacer(),
              if (_hasActiveFilters())
                TextButton(onPressed: onClearFilters, child: const Text('Clear all')),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 220,
                child: SingleLineInput(
                  hintText: 'Work Item ID',
                  onChanged: (v) {
                    workItemIdController.text = v;
                    _applyFilters();
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: SingleLineInput(
                  hintText: 'Provider',
                  onChanged: (v) {
                    providerController.text = v;
                    _applyFilters();
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: SingleLineInput(
                  hintText: 'Model ID',
                  onChanged: (v) {
                    modelIdController.text = v;
                    _applyFilters();
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownMenu<String>(
                  initialSelection: taskTypeFilter,
                  label: const Text('Task Type'),
                  dropdownMenuEntries: [
                    const DropdownMenuEntry(value: '', label: 'All types'),
                    for (final t in taskTypes)
                      DropdownMenuEntry(value: t, label: t),
                  ],
                  onSelected: (value) => _applyFilters(taskType: value?.isEmpty == true ? null : value),
                ),
              ),
              SizedBox(
                width: 140,
                child: DropdownMenu<bool?>(
                  initialSelection: successFilter,
                  label: const Text('Success'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: null, label: 'All'),
                    DropdownMenuEntry(value: true, label: 'Success'),
                    DropdownMenuEntry(value: false, label: 'Failed'),
                  ],
                  onSelected: (value) => _applyFilters(success: value),
                ),
              ),
              SizedBox(
                width: 300,
                child: _DateRangeField(
                  value: dateRange,
                  onChanged: onDateRangeChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return workItemIdController.text.isNotEmpty ||
        providerController.text.isNotEmpty ||
        modelIdController.text.isNotEmpty ||
        taskTypeFilter != null ||
        successFilter != null ||
        dateRange != null;
  }

  void _applyFilters({
    String? taskType,
    bool? success,
  }) {
    onFilterChanged(_Filters(
      workItemId: workItemIdController.text,
      provider: providerController.text,
      modelId: modelIdController.text,
      taskType: taskType ?? taskTypeFilter,
      success: success ?? successFilter,
      dateRange: dateRange,
    ));
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({
    required this.value,
    required this.onChanged,
  });

  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: () => _pickRange(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date Range',
          labelStyle: ShipItType.ref.copyWith(color: palette.inkTertiary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ShipItMetrics.radius),
            borderSide: BorderSide(color: palette.cardBorder),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(
          value == null
              ? 'All time'
              : '${_formatDate(value!.start)} – ${_formatDate(value!.end)}',
          style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
        ),
      ),
    );
  }

Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final initialRange = value ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: initialRange,
    );
    if (picked != null) onChanged(picked);
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _ExecutionsTable extends StatelessWidget {
  const _ExecutionsTable({
    required this.rows,
    required this.emptyMessage,
  });

  final List<ModelExecutionRecordResponse> rows;
  final String emptyMessage;

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
              SizedBox(width: ShipItMetrics.colWhat, child: MicroLabel('WORK ITEM')),
              SizedBox(width: 100, child: MicroLabel('JOB')),
              SizedBox(width: 120, child: MicroLabel('ROLE')),
              SizedBox(width: 160, child: MicroLabel('MODEL')),
              SizedBox(width: 100, child: MicroLabel('PROVIDER')),
              SizedBox(width: 120, child: MicroLabel('TASK TYPE')),
              SizedBox(width: 80, child: MicroLabel('COST')),
              SizedBox(width: 80, child: MicroLabel('TOKENS')),
              SizedBox(width: 70, child: MicroLabel('RESULT')),
              SizedBox(width: 50, child: MicroLabel('ESC')),
              SizedBox(width: 160, child: MicroLabel('STARTED')),
            ],
          ),
        ),
        const ContentRule(strong: true),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              emptyMessage,
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            ),
          )
        else
          for (final row in rows) _ExecutionTableRow(row: row),
      ],
    );
  }
}

class _ExecutionTableRow extends StatelessWidget {
  const _ExecutionTableRow({required this.row});

  final ModelExecutionRecordResponse row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: () => context.go('/runs/${row.workItemId}'),
      child: Column(
        children: [
          SizedBox(
            height: ShipItMetrics.rowPitch - ShipItMetrics.hairline,
            child: Row(
              children: [
                SizedBox(
                  width: ShipItMetrics.colWhat,
                  child: Text(
                    row.workItemId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ShipItType.ref.copyWith(color: palette.inkSecondary),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    row.jobId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    _formatRole(row.role),
                    style: ShipItType.monoMeta.copyWith(color: palette.inkSecondary),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: Text(
                    row.modelId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ShipItType.ref.copyWith(color: palette.inkPrimary),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    row.provider,
                    style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    row.taskType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ShipItType.monoMeta.copyWith(color: palette.inkSecondary),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '\$${row.costUsd.toStringAsFixed(4)}',
                    textAlign: TextAlign.right,
                    style: ShipItType.duration.copyWith(color: palette.inkPrimary),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${_formatTokens(row.totalTokens)}',
                    textAlign: TextAlign.right,
                    style: ShipItType.duration.copyWith(color: palette.inkTertiary),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: row.success ? palette.positive : palette.negative,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        row.success ? 'OK' : 'FAIL',
                        style: ShipItType.status.copyWith(
                          color: row.success ? palette.positive : palette.negative,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    row.escalationIndex.toString(),
                    textAlign: TextAlign.center,
                    style: ShipItType.monoMeta.copyWith(
                      color: row.escalationIndex > 0 ? palette.attention : palette.inkTertiary,
                      fontWeight: row.escalationIndex > 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: Text(
                    _formatDateTime(row.startedAt),
                    style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
                  ),
                ),
              ],
            ),
          ),
          const ContentRule(),
        ],
      ),
    );
  }

  String _formatRole(String role) {
    return role
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }

  String _formatDateTime(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
  });

  final int totalCount;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final totalPages = (totalCount / pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          'Page ${page + 1} of $totalPages',
          style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
        ),
        IconButton(
          onPressed: page < totalPages - 1 ? () => onPageChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _MobileModelExecutions extends StatelessWidget {
  const _MobileModelExecutions({
    required this.rows,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    required this.filters,
    required this.onFilterChanged,
    required this.onClearFilters,
    required this.taskTypes,
  });

  final List<ModelExecutionRecordResponse> rows;
  final int totalCount;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final _Filters filters;
  final ValueChanged<_Filters> onFilterChanged;
  final VoidCallback onClearFilters;
  final List<String> taskTypes;

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
            Text('Model Executions', style: ShipItType.pageTitle.copyWith(color: palette.inkPrimary)),
            const SizedBox(height: 6),
            Text(
              '${rows.length} of $totalCount executions',
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
            const SizedBox(height: 18),
            const ContentRule(strong: true),
            _MobileFilterCard(
              filters: filters,
              taskTypes: taskTypes,
              onFilterChanged: onFilterChanged,
              onClearFilters: onClearFilters,
            ),
            const SizedBox(height: 16),
            const ContentRule(),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No executions match the current filters.',
                  style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
                ),
              )
            else
              for (final row in rows) _MobileExecutionCard(row: row),
            const SizedBox(height: 16),
            _PaginationControls(
              totalCount: totalCount,
              page: page,
              pageSize: pageSize,
              onPageChanged: onPageChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileFilterCard extends StatelessWidget {
  const _MobileFilterCard({
    required this.filters,
    required this.taskTypes,
    required this.onFilterChanged,
    required this.onClearFilters,
  });

  final _Filters filters;
  final List<String> taskTypes;
  final ValueChanged<_Filters> onFilterChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Filters', style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary)),
            const Spacer(),
            if (_hasActiveFilters())
              TextButton(onPressed: onClearFilters, child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 12),
        DesignTextField(
          initialValue: filters.workItemId,
          label: 'Work Item ID',
          onChanged: (v) => onFilterChanged(filters.copyWith(workItemId: v)),
        ),
        const SizedBox(height: 12),
        DesignTextField(
          initialValue: filters.provider,
          label: 'Provider',
          onChanged: (v) => onFilterChanged(filters.copyWith(provider: v)),
        ),
        const SizedBox(height: 12),
        DesignTextField(
          initialValue: filters.modelId,
          label: 'Model ID',
          onChanged: (v) => onFilterChanged(filters.copyWith(modelId: v)),
        ),
        const SizedBox(height: 12),
        DropdownMenu<String>(
          initialSelection: filters.taskType,
          label: const Text('Task Type'),
          dropdownMenuEntries: [
            const DropdownMenuEntry(value: '', label: 'All types'),
            for (final t in taskTypes)
              DropdownMenuEntry(value: t, label: t),
          ],
          onSelected: (v) => onFilterChanged(filters.copyWith(taskType: v?.isEmpty == true ? null : v)),
        ),
        const SizedBox(height: 12),
        DropdownMenu<bool?>(
          initialSelection: filters.success,
          label: const Text('Success'),
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: null, label: 'All'),
            DropdownMenuEntry(value: true, label: 'Success'),
            DropdownMenuEntry(value: false, label: 'Failed'),
          ],
          onSelected: (v) => onFilterChanged(filters.copyWith(success: v)),
        ),
      ],
    );
  }

  bool _hasActiveFilters() {
    return filters.workItemId.isNotEmpty ||
        filters.provider.isNotEmpty ||
        filters.modelId.isNotEmpty ||
        filters.taskType != null ||
        filters.success != null ||
        filters.dateRange != null;
  }
}

class _MobileExecutionCard extends StatelessWidget {
  const _MobileExecutionCard({required this.row});

  final ModelExecutionRecordResponse row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: () => context.go('/runs/${row.workItemId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AccentTick(color: row.success ? palette.positive : palette.negative, height: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(row.workItemId, style: ShipItType.rowTitle.copyWith(color: palette.inkPrimary)),
                          const SizedBox(width: 8),
                          Text(
                            row.jobId,
                            style: ShipItType.ref.copyWith(color: palette.inkTertiary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _Chip(label: _formatRole(row.role), color: palette.accent),
                          _Chip(label: row.modelId, color: palette.inkSecondary),
                          _Chip(label: row.provider, color: palette.inkTertiary),
                          _Chip(label: row.taskType, color: palette.inkTertiary),
                          if (row.escalationIndex > 0)
                            _Chip(label: 'Escalation ${row.escalationIndex}', color: palette.attention),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '\$${row.costUsd.toStringAsFixed(4)} · ${_formatTokens(row.totalTokens)} tokens',
                            style: ShipItType.monoMeta.copyWith(color: palette.inkSecondary),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: row.success ? palette.positive : palette.negative,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            row.success ? 'Success' : 'Failed',
                            style: ShipItType.status.copyWith(
                              color: row.success ? palette.positive : palette.negative,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatDateTime(row.startedAt),
                        style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRole(String role) {
    return role
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }

  String _formatDateTime(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: ShipItType.monoMeta.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

extension _FiltersCopy on _Filters {
  _Filters copyWith({
    String? workItemId,
    String? provider,
    String? modelId,
    String? taskType,
    bool? success,
    DateTimeRange? dateRange,
  }) {
    return _Filters(
      workItemId: workItemId ?? this.workItemId,
      provider: provider ?? this.provider,
      modelId: modelId ?? this.modelId,
      taskType: taskType ?? this.taskType,
      success: success ?? this.success,
      dateRange: dateRange ?? this.dateRange,
    );
  }
}