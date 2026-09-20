import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/product_language.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../shared/design_primitives.dart';
import '../../shared/mobile_chrome.dart';
import '../../shared/state_views.dart';
import 'products_bloc.dart';

/// The "Products" screen.
///
/// Transcribed from the Penpot board `BP · Products` (light/dark): header,
/// six mono filter tabs with a 2px active underline, a count, then a
/// REF / PRODUCT / BASELINE / STATUS table, followed by the Access section.
///
/// One deliberate departure from the board: the board's `FILES` column showed
/// a file count. The registry records baseline *facts* — claims with a
/// provenance and maturity — and never counts files, so the column reads
/// `FACTS` and is fed by `baselineFactCount`. Showing "412 files" would have
/// been a number the system cannot produce.
class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key, this.bloc});

  /// Test-only dependency seam. When null the page builds its own bloc from
  /// `ClientProvider.repository` (production path).
  final ProductsBloc? bloc;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<ProductsBloc>.value(
            value: provided,
            child: const _ProductsView(),
          )
        : BlocProvider<ProductsBloc>(
            create: (_) =>
                ProductsBloc(repository: ClientProvider.repository)
                  ..add(const ProductsLoaded()),
            child: const _ProductsView(),
          );
  }
}

class _ProductsView extends StatefulWidget {
  const _ProductsView();

  @override
  State<_ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<_ProductsView> {
  ProductFilter _filter = ProductFilter.all;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductsBloc, ProductsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const DesignLoadingSkeleton(
            title: 'Products',
            showColumns: true,
          );
        }
        if (state.errorMessage != null) {
          return DesignErrorState(
            title: "We could not reach the system's records.",
            detail: state.errorMessage!,
            onRetry: () =>
                context.read<ProductsBloc>().add(const ProductsLoaded()),
          );
        }

        final rows = state.products
            .where((p) => _filter.matches(p.status))
            .toList();

        if (isMobile(context)) {
          return _MobileProducts(
            rows: rows,
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
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
                  title: 'Products',
                  subtitle: ProductLanguage.summary(
                    state.products.map((p) => p.status).toList(),
                  ),
                  liveLabel: 'LIVE',
                ),
                const SizedBox(height: 25),
                FilterTabs(
                  labels: ProductFilter.values.map((f) => f.label).toList(),
                  activeIndex: ProductFilter.values.indexOf(_filter),
                  onSelected: (i) =>
                      setState(() => _filter = ProductFilter.values[i]),
                ),
                const SizedBox(height: 24),
                Text(
                  '${rows.length} '
                  '${rows.length == 1 ? 'product' : 'products'}',
                  style: ShipItType.sectionTitle.copyWith(
                    color: context.palette.inkPrimary,
                  ),
                ),
                const SizedBox(height: 9),
                _ProductTable(rows: rows, emptyMessage: _filter.emptyMessage),
                const SizedBox(height: 24),
                const _AddProductAction(),
                const SizedBox(height: 40),
                _AccessSection(rows: rows),
                const SizedBox(height: 46),
                TechnicalDetails(
                  note:
                      'Every row comes straight from the registry. '
                      'FACTS counts recorded baseline claims, not files — '
                      'the registry does not track file counts.',
                  lines: [
                    'filter=${_filter.name} · '
                        'shown=${rows.length}/${state.products.length}',
                    for (final p in state.products)
                      '${p.productId} Product.state=${p.stateWire} · '
                          'allowsDispatch=${p.allowsDispatch} · '
                          'baseline=${p.baselineLabel} · '
                          'facts=${p.factCount} · '
                          'repos=${p.reachableRepositoryCount}/'
                          '${p.repositoryCount} reachable'
                          '${p.openClarifications > 0 ? ' · ${p.openClarifications} open clarification(s)' : ''}'
                          '${p.isBlockedOnVerification ? ' · BLOCKED: baseline not independently verified' : ''}',
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// REF / PRODUCT / BASELINE / STATUS / FACTS.
class _ProductTable extends StatelessWidget {
  const _ProductTable({required this.rows, required this.emptyMessage});

  final List<ProductRow> rows;
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
              SizedBox(width: ShipItMetrics.colWhat, child: MicroLabel('REF')),
              Expanded(child: MicroLabel('PRODUCT')),
              SizedBox(width: 210, child: MicroLabel('BASELINE')),
              SizedBox(width: 190, child: MicroLabel('STATUS')),
              SizedBox(width: 70, child: MicroLabel('FACTS')),
              SizedBox(width: 140),
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
          for (final row in rows) _ProductTableRow(row: row),
      ],
    );
  }
}

class _ProductTableRow extends StatelessWidget {
  const _ProductTableRow({required this.row});

  final ProductRow row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = row.status;
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
                      color: status.tickColor(palette),
                      height: ShipItMetrics.rowTickHeight,
                    ),
                    const SizedBox(width: ShipItMetrics.colRefInset - 2),
                    Expanded(
                      child: Text(
                        'ref ${row.productId}',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: ShipItType.ref.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShipItType.rowTitle.copyWith(
                    color: palette.inkPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: 210,
                child: Text(
                  row.baselineLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShipItType.status.copyWith(
                    color: row.isBlockedOnVerification
                        ? palette.negative
                        : palette.inkTertiary,
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: Text(
                  status.label,
                  style: ShipItType.status.copyWith(
                    color: status.textColor(palette),
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  row.factCount == 0 ? '—' : '${row.factCount}',
                  textAlign: TextAlign.right,
                  style: ShipItType.duration.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InlineLink(
                    label: 'See details',
                    onTap: () => context.go('/products/${row.productId}'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const ContentRule(),
      ],
    );
  }
}

class _AddProductAction extends StatelessWidget {
  const _AddProductAction();

  @override
  Widget build(BuildContext context) =>
      InlineLink(label: '+ Add a product', onTap: () {});
}

/// Per-repository credential inventory (ADR 0018 A1).
///
/// One row per product rather than per credential, because the screen's job
/// here is "can ShipIt reach this product's repositories?" — the per-repository
/// detail lives on the product's credentials screen.
class _AccessSection extends StatelessWidget {
  const _AccessSection({required this.rows});

  final List<ProductRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ContentRule(),
        const SizedBox(height: 18),
        Text(
          'Access',
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'One key per repository. A key that leaks reaches one repository, '
          'not all of them.',
          style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(bottom: 7),
          child: Row(
            children: [
              Expanded(child: MicroLabel('PRODUCT')),
              SizedBox(width: 200, child: MicroLabel('REPOSITORIES')),
              SizedBox(width: 220, child: MicroLabel('ACCESS')),
              SizedBox(width: 140),
            ],
          ),
        ),
        const ContentRule(strong: true),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No products are registered yet.',
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            ),
          )
        else
          for (final row in rows) _AccessRow(row: row),
      ],
    );
  }
}

class _AccessRow extends StatelessWidget {
  const _AccessRow({required this.row});

  final ProductRow row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reachable =
        row.repositoryCount > 0 &&
        row.reachableRepositoryCount == row.repositoryCount;
    final none = row.repositoryCount == 0 || row.reachableRepositoryCount == 0;
    return Column(
      children: [
        SizedBox(
          height: 30,
          child: Row(
            children: [
              Row(
                children: [
                  AccentTick(
                    color: reachable
                        ? palette.positive
                        : none
                        ? palette.attentionTick
                        : palette.accentTick,
                    height: 14,
                  ),
                  const SizedBox(width: ShipItMetrics.colRefInset - 2),
                ],
              ),
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShipItType.rowTitle.copyWith(
                    color: palette.inkPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: Text(
                  row.repositoryCount == 0
                      ? 'none attributed'
                      : '${row.repositoryCount}',
                  style: ShipItType.status.copyWith(color: palette.inkTertiary),
                ),
              ),
              SizedBox(
                width: 220,
                child: Text(
                  row.accessLabel,
                  style: ShipItType.status.copyWith(
                    color: reachable
                        ? palette.positive
                        : none
                        ? palette.attention
                        : palette.inkSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InlineLink(
                    label: row.repositoryCount == 0 ? 'Add a repo' : 'Manage',
                    onTap: () => context.go('/products/${row.productId}'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const ContentRule(),
      ],
    );
  }
}

/// Mobile: the table collapses to stacked rows; the Access section becomes a
/// line on each row rather than a second table.
class _MobileProducts extends StatelessWidget {
  const _MobileProducts({
    required this.rows,
    required this.filter,
    required this.onFilter,
  });

  final List<ProductRow> rows;
  final ProductFilter filter;
  final ValueChanged<ProductFilter> onFilter;

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
              'Products',
              style: ShipItType.pageTitle.copyWith(color: palette.inkPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              ProductLanguage.summary(rows.map((p) => p.status).toList()),
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FilterTabs(
                labels: ProductFilter.values.map((f) => f.label).toList(),
                activeIndex: ProductFilter.values.indexOf(filter),
                onSelected: (i) => onFilter(ProductFilter.values[i]),
              ),
            ),
            const SizedBox(height: 18),
            const ContentRule(strong: true),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  filter.emptyMessage,
                  style: ShipItType.bodySmall.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              )
            else
              for (final row in rows) _MobileProductRow(row: row),
            const SizedBox(height: 20),
            const _AddProductAction(),
          ],
        ),
      ),
    );
  }
}

class _MobileProductRow extends StatelessWidget {
  const _MobileProductRow({required this.row});

  final ProductRow row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = row.status;
    return Column(
      children: [
        InkWell(
          onTap: () => context.go('/products/${row.productId}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AccentTick(color: status.tickColor(palette), height: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        style: ShipItType.rowTitle.copyWith(
                          color: palette.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'ref ${row.productId}',
                            style: ShipItType.ref.copyWith(
                              color: palette.inkTertiary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              status.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ShipItType.status.copyWith(
                                color: status.textColor(palette),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        row.baselineLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShipItType.monoMeta.copyWith(
                          color: palette.inkTertiary,
                        ),
                      ),
                      Text(
                        'access: ${row.accessLabel}',
                        style: ShipItType.monoMeta.copyWith(
                          color: palette.inkTertiary,
                        ),
                      ),
                      if (row.isBlockedOnVerification)
                        Text(
                          'baseline not verified',
                          style: ShipItType.monoMeta.copyWith(
                            color: palette.negative,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const ContentRule(),
      ],
    );
  }
}
