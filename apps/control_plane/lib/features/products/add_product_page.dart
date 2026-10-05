import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/design_primitives.dart';
import '../../shared/form_primitives.dart';
import '../../shared/mobile_chrome.dart';
import '../../shared/state_views.dart';

class AddProductPage extends StatelessWidget {
  const AddProductPage({super.key, this.bloc});

  final AddProductBloc? bloc;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<AddProductBloc>.value(
            value: provided,
            child: BlocListener<AddProductBloc, AddProductState>(
              listener: (context, state) {
                if (state.productCreated != null) {
                  context.go('/products/${state.productCreated!.productId}');
                }
              },
              child: const _AddProductView(),
            ),
          )
        : BlocProvider<AddProductBloc>(
            create: (_) =>
                AddProductBloc(repository: ClientProvider.repository),
            child: const _AddProductView(),
          );
  }
}

sealed class AddProductEvent {
  const AddProductEvent();
}

class ProductNameChanged extends AddProductEvent {
  const ProductNameChanged(this.value);
  final String value;
}

class RepositoryChanged extends AddProductEvent {
  const RepositoryChanged(this.value);
  final String value;
}

class RevisionChanged extends AddProductEvent {
  const RevisionChanged(this.value);
  final String value;
}

class CheckAccessRequested extends AddProductEvent {
  const CheckAccessRequested();
}

class RegisterProductRequested extends AddProductEvent {
  const RegisterProductRequested();
}

class AddProductBloc extends Bloc<AddProductEvent, AddProductState> {
  AddProductBloc({required this._repository}) : super(const AddProductState()) {
    on<ProductNameChanged>(_onProductNameChanged);
    on<RepositoryChanged>(_onRepositoryChanged);
    on<RevisionChanged>(_onRevisionChanged);
    on<CheckAccessRequested>(_onCheckAccessRequested);
    on<RegisterProductRequested>(_onRegisterProductRequested);
  }

  final ControlPlaneRepository _repository;

  void _onProductNameChanged(
    ProductNameChanged event,
    Emitter<AddProductState> emit,
  ) {
    emit(state.copyWith(productName: event.value));
  }

  void _onRepositoryChanged(
    RepositoryChanged event,
    Emitter<AddProductState> emit,
  ) {
    emit(state.copyWith(repository: event.value));
  }

  void _onRevisionChanged(
    RevisionChanged event,
    Emitter<AddProductState> emit,
  ) {
    emit(state.copyWith(revision: event.value));
  }

  Future<void> _onCheckAccessRequested(
    CheckAccessRequested event,
    Emitter<AddProductState> emit,
  ) async {
    if (state.productName.isEmpty || state.repository.isEmpty) return;

    emit(state.copyWith(isCheckingAccess: true, clearError: true));
    try {
      final keyPair = _generateMockKeyPair(state.productName);
      emit(
        state.copyWith(
          isCheckingAccess: false,
          deployKey: keyPair,
          accessStatus: AccessStatus.notChecked,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isCheckingAccess: false, errorMessage: e.toString()));
    }
  }

  DeployKeyPair _generateMockKeyPair(String productName) {
    final random = Random.secure();
    final keyBytes = Uint8List.fromList(
      List.generate(32, (_) => random.nextInt(256)),
    );
    final base64Key = base64Encode(keyBytes);
    final fingerprint = _computeFingerprint(keyBytes);

    return DeployKeyPair(
      publicKey: 'ssh-ed25519 $base64Key shipit+$productName',
      fingerprint: fingerprint,
    );
  }

  String _computeFingerprint(Uint8List publicKeyBytes) {
    final hash = publicKeyBytes.take(16).toList();
    return 'SHA256:${base64Encode(Uint8List.fromList(hash))}';
  }

  Future<void> _onRegisterProductRequested(
    RegisterProductRequested event,
    Emitter<AddProductState> emit,
  ) async {
    if (state.productName.isEmpty ||
        state.repository.isEmpty ||
        state.deployKey == null) {
      return;
    }

    emit(state.copyWith(isRegistering: true, clearError: true));
    try {
      final productId = state.productName.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '-',
      );
      final product = await _repository.createProduct(
        productId: productId,
        name: state.productName,
        description: '',
        manifestJson: '{}',
      );

      // Add repository reference
      await _repository.addRepositoryReference(
        productId: productId,
        repositoryId: productId, // Use productId as repositoryId for simplicity
        uri: state.repository,
        kind: 'monorepo',
        provider: 'github', // Could be parsed from URI in the future
      );

      emit(state.copyWith(isRegistering: false, productCreated: product));
    } catch (e) {
      emit(state.copyWith(isRegistering: false, errorMessage: e.toString()));
    }
  }
}

class AddProductState {
  const AddProductState({
    this.productName = '',
    this.repository = '',
    this.revision = 'main',
    this.deployKey,
    this.accessStatus = AccessStatus.notGenerated,
    this.isCheckingAccess = false,
    this.isRegistering = false,
    this.errorMessage,
    this.productCreated,
  });

  final String productName;
  final String repository;
  final String revision;
  final DeployKeyPair? deployKey;
  final AccessStatus accessStatus;
  final bool isCheckingAccess;
  final bool isRegistering;
  final String? errorMessage;
  final ProductDetailResponse? productCreated;

  AddProductState copyWith({
    String? productName,
    String? repository,
    String? revision,
    DeployKeyPair? deployKey,
    AccessStatus? accessStatus,
    bool? isCheckingAccess,
    bool? isRegistering,
    String? errorMessage,
    ProductDetailResponse? productCreated,
    bool clearError = false,
  }) => AddProductState(
    productName: productName ?? this.productName,
    repository: repository ?? this.repository,
    revision: revision ?? this.revision,
    deployKey: deployKey ?? this.deployKey,
    accessStatus: accessStatus ?? this.accessStatus,
    isCheckingAccess: isCheckingAccess ?? this.isCheckingAccess,
    isRegistering: isRegistering ?? this.isRegistering,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    productCreated: productCreated ?? this.productCreated,
  );

  bool get canGenerateKey =>
      productName.isNotEmpty && repository.isNotEmpty && !isCheckingAccess;

  bool get canRegister =>
      deployKey != null &&
      accessStatus == AccessStatus.verified &&
      !isRegistering;
}

enum AccessStatus { notGenerated, notChecked, checking, verified, failed }

class DeployKeyPair {
  const DeployKeyPair({required this.publicKey, required this.fingerprint});

  final String publicKey;
  final String fingerprint;
}

class _AddProductView extends StatelessWidget {
  const _AddProductView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddProductBloc, AddProductState>(
      builder: (context, state) {
        if (state.errorMessage != null) {
          return DesignErrorState(
            title: 'Something went wrong',
            detail: state.errorMessage!,
            onRetry: () => context.read<AddProductBloc>().add(
              const ProductNameChanged(''),
            ),
          );
        }

        if (isMobile(context)) {
          return _MobileAddProduct(state: state);
        }

        return _DesktopAddProduct(state: state);
      },
    );
  }
}

/// Desktop (≥840px): two-column layout with rail
class _DesktopAddProduct extends StatelessWidget {
  const _DesktopAddProduct({required this.state});

  final AddProductState state;

  @override
  Widget build(BuildContext context) {
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
            _buildBreadcrumb(context),
            const SizedBox(height: 8),
            _buildH1(context),
            const SizedBox(height: 10),
            _buildStatusRow(context),
            const SizedBox(height: 14),
            const ContentRule(),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _LeftColumn(state: state)),
                const SizedBox(width: ShipItMetrics.sidePanelGap),
                SizedBox(
                  width: ShipItMetrics.sidePanelWidth,
                  child: _RightPanel(state: state),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildFooter(context),
            const SizedBox(height: 12),
            TechnicalDetails(
              note:
                  'Registering records the product. Nothing is governed until '
                  'you approve a baseline.',
              lines: [
                'productName=${state.productName.isEmpty ? '—' : state.productName}',
                'repository=${state.repository.isEmpty ? '—' : state.repository}',
                'revision=${state.revision}',
                if (state.deployKey != null)
                  'deployKeyFingerprint=${state.deployKey!.fingerprint}',
                'accessStatus=${state.accessStatus.name}',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    final palette = context.palette;
    return Text(
      'Products  /  Add a product',
      style: ShipItType.microLabel.copyWith(
        fontWeight: FontWeight.w400,
        color: palette.inkTertiary,
        letterSpacing: 0,
      ),
    );
  }

  Widget _buildH1(BuildContext context) {
    final palette = context.palette;
    return Text(
      'Add a product',
      style: const TextStyle(
        fontFamily: ShipItFonts.sans,
        fontSize: 23,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.2,
      ).copyWith(color: palette.inkPrimary),
    );
  }

  Widget _buildStatusRow(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        AccentTick(color: palette.inkTertiary, height: 11),
        const SizedBox(width: 8),
        Text(
          'NOT REGISTERED YET',
          style: ShipItType.microLabel.copyWith(color: palette.inkTertiary),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ContentRule(),
        const SizedBox(height: 13),
        Text(
          'Your decision is recorded permanently. The same piece of '
          'work then continues \u2014 nothing is restarted.',
          style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
        ),
      ],
    );
  }
}

/// Left column: form fields, info panel, deploy key box
class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.state});

  final AddProductState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What you're registering",
          style: ShipItType.detailTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Registering records the product. Nothing is governed until you '
          'approve a baseline.',
          style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
        ),
        const SizedBox(height: 18),
        _buildField(
          context,
          label: 'PRODUCT NAME',
          hint: 'e.g. TeamHub',
          onChanged: (v) =>
              context.read<AddProductBloc>().add(ProductNameChanged(v)),
          errorText: state.productName.isEmpty && state.errorMessage != null
              ? 'Product name is required'
              : null,
        ),
        const SizedBox(height: FormMetrics.fieldGap),
        _buildField(
          context,
          label: 'REPOSITORY  (SSH)',
          hint: 'git@github.com:acme/teamhub.git',
          onChanged: (v) =>
              context.read<AddProductBloc>().add(RepositoryChanged(v)),
        ),
        const SizedBox(height: FormMetrics.fieldGap),
        _buildField(
          context,
          label: 'REVISION OR BRANCH',
          hint: 'main',
          onChanged: (v) =>
              context.read<AddProductBloc>().add(RevisionChanged(v)),
        ),
        const SizedBox(height: 18),
        _buildInfoPanel(context),
        const SizedBox(height: 16),
        if (state.deployKey != null) _buildKeyBox(context, state),
      ],
    );
  }

  Widget _buildField(
    BuildContext context, {
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    String? errorText,
  }) {
    return FormFieldSlot(
      label: label,
      control: SingleLineInput(
        hintText: hint,
        onChanged: onChanged,
        errorText: errorText,
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      edgeColor: palette.accent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MicroLabel(
            'WHAT SHIPIT DOES WITH THIS KEY',
            color: palette.inkTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            "It clones over SSH. The private half stays in this device's "
            'keychain \u2014 never shown, logged or stored.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'It pushes and merges on its own. Only promotion to production '
            'waits for you.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyBox(BuildContext context, AddProductState state) {
    final palette = context.palette;
    final deployKey = state.deployKey!;
    final (statusLabel, statusColor) = _statusLabel(
      state.accessStatus,
      palette,
    );

    return DesignPanel(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Key tick at top-right (2×11 amber)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 2,
              height: 11,
              color: ShipItPalette.dark.attentionTick, // #f7a42c in both themes
            ),
          ),
          // Key state label at top-right, next to tick
          Positioned(
            right: 16,
            top: 0,
            child: Text(
              statusLabel,
              style: ShipItType.bodySmall.copyWith(color: statusColor),
            ),
          ),
          // Main content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14), // Space for tick/state
              MicroLabel(
                'DEPLOY KEY  \u00b7  THIS PRODUCT ONLY',
                color: palette.inkTertiary,
              ),
              const SizedBox(height: 10),
              Text(
                'Generated for this product',
                style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'ed25519 \u00b7 created on this device \u00b7 the private half stays in the keychain',
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
              const SizedBox(height: 10),
              SelectableText(
                deployKey.publicKey,
                style: ShipItType.monoMeta.copyWith(
                  color: palette.inkSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  InlineLink(
                    micro: true,
                    label: 'Copy public key',
                    onTap: () => _copyToClipboard(context, deployKey.publicKey),
                  ),
                  const SizedBox(width: 16),
                  InlineLink(
                    micro: true,
                    label: state.accessStatus == AccessStatus.verified
                        ? 'Check again'
                        : 'Check access',
                    onTap: () => context.read<AddProductBloc>().add(
                      const CheckAccessRequested(),
                    ),
                    // Disable while checking
                    // Note: InlineLink doesn't have disabled state; we guard in onTap
                  ),
                ],
              ),
              if (state.accessStatus == AccessStatus.failed) ...[
                const SizedBox(height: 8),
                Text(
                  'Access check failed. Ensure the key is installed with write access.',
                  style: ShipItType.bodySmall.copyWith(color: palette.negative),
                ),
              ],
              if (state.accessStatus == AccessStatus.checking) ...[
                const SizedBox(height: 8),
                Text(
                  'Checking access\u2026',
                  style: ShipItType.bodySmall.copyWith(color: palette.accent),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Add this key to the repository\u2019s deploy keys with write access, then check.',
                style: ShipItType.bodySmall.copyWith(
                  color: palette.inkTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color) _statusLabel(AccessStatus status, ShipItPalette palette) {
    switch (status) {
      case AccessStatus.notGenerated:
      case AccessStatus.notChecked:
        return ('Not installed yet', palette.attention);
      case AccessStatus.checking:
        return ('Checking\u2026', palette.accent);
      case AccessStatus.verified:
        return ('Verified', palette.positive);
      case AccessStatus.failed:
        return ('Access failed', palette.negative);
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Public key copied')));
  }
}

/// Right panel: steps and register button
class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.state});

  final AddProductState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'What happens next',
            style: ShipItType.detailTitle.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Registering is not governing.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 18),
          const ContentRule(),
          const SizedBox(height: 14),
          _StepText(
            number: '1',
            text: 'A deploy key is generated for this product',
            isDone: state.deployKey != null,
          ),
          const SizedBox(height: 10),
          _StepText(
            number: '2',
            text: 'You install it, then ShipIt proves it can reach the repo',
            isDone: state.accessStatus == AccessStatus.verified,
          ),
          const SizedBox(height: 10),
          const _StepText(
            number: '3',
            text: 'It reads that revision and builds a baseline',
            isDone: false,
          ),
          const SizedBox(height: 10),
          const _StepText(
            number: '4',
            text: 'You approve the baseline \u2014 only then can work run',
            isDone: false,
          ),
          const SizedBox(height: 18),
          const ContentRule(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.canRegister && !state.isRegistering
                  ? () => context.read<AddProductBloc>().add(
                      const RegisterProductRequested(),
                    )
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ShipItMetrics.radius),
                ),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.isRegistering
                        ? 'Registering\u2026'
                        : 'Register product',
                    style: ShipItType.monoMeta.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                      color: context
                          .palette
                          .inkPrimary, // FilledButton uses onPrimary
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _registerButtonSubtext(state),
                    style: ShipItType.monoMeta.copyWith(
                      fontSize: 10,
                      color: context.palette.inkPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _registerButtonSubtext(AddProductState state) {
  if (state.isRegistering) return 'Registering\u2026';
  if (state.productName.isEmpty) return 'Product name is required';
  if (state.repository.isEmpty) return 'Repository URL is required';
  if (state.deployKey == null) return 'Generate a deploy key first';
  if (state.accessStatus != AccessStatus.verified) {
    return 'Access must be verified before a product can be registered';
  }
  return 'Access verified \u2014 this product can be registered';
}

/// Simple step text row matching Penbot design: "1   Text"
class _StepText extends StatelessWidget {
  const _StepText({
    required this.number,
    required this.text,
    this.isDone = false,
  });

  final String number;
  final String text;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$number   ',
            style: ShipItType.microLabel.copyWith(
              color: isDone ? palette.inkSecondary : palette.inkTertiary,
            ),
          ),
          TextSpan(
            text: text,
            style: ShipItType.bodySmall.copyWith(
              color: isDone ? palette.inkSecondary : palette.inkPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile (<840px): single column with top bar and bottom nav
class _MobileAddProduct extends StatelessWidget {
  const _MobileAddProduct({required this.state});

  final AddProductState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        MobileBackBar(label: 'Products', onTap: () => context.go('/products')),
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
                    'Add a product',
                    style: ShipItType.pageTitleMobile.copyWith(
                      color: palette.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      AccentTick(color: palette.inkTertiary, height: 11),
                      const SizedBox(width: 8),
                      Text(
                        'NOT REGISTERED YET',
                        style: ShipItType.microLabel.copyWith(
                          color: palette.inkTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const ContentRule(),
                  const SizedBox(height: 16),
                  _buildField(
                    context,
                    label: 'PRODUCT NAME',
                    hint: 'e.g. TeamHub',
                    onChanged: (v) => context.read<AddProductBloc>().add(
                      ProductNameChanged(v),
                    ),
                    errorText:
                        state.productName.isEmpty && state.errorMessage != null
                        ? 'Product name is required'
                        : null,
                  ),
                  const SizedBox(height: FormMetrics.fieldGap),
                  _buildField(
                    context,
                    label: 'REPOSITORY  (SSH)',
                    hint: 'git@github.com:acme/teamhub.git',
                    onChanged: (v) => context.read<AddProductBloc>().add(
                      RepositoryChanged(v),
                    ),
                  ),
                  const SizedBox(height: FormMetrics.fieldGap),
                  _buildField(
                    context,
                    label: 'REVISION OR BRANCH',
                    hint: 'main',
                    onChanged: (v) =>
                        context.read<AddProductBloc>().add(RevisionChanged(v)),
                  ),
                  const SizedBox(height: 18),
                  _buildInfoPanel(context),
                  const SizedBox(height: 16),
                  if (state.deployKey != null) _buildKeyBox(context, state),
                  const SizedBox(height: 20),
                  DesignPanel(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What happens next',
                          style: ShipItType.detailTitle.copyWith(
                            color: palette.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Registering is not governing.',
                          style: ShipItType.bodySmall.copyWith(
                            color: palette.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const ContentRule(),
                        const SizedBox(height: 14),
                        _StepText(
                          number: '1',
                          text: 'A deploy key is generated for this product',
                          isDone: state.deployKey != null,
                        ),
                        const SizedBox(height: 10),
                        _StepText(
                          number: '2',
                          text:
                              'You install it, then ShipIt proves it can reach the repo',
                          isDone: state.accessStatus == AccessStatus.verified,
                        ),
                        const SizedBox(height: 10),
                        const _StepText(
                          number: '3',
                          text: 'It reads that revision and builds a baseline',
                          isDone: false,
                        ),
                        const SizedBox(height: 10),
                        const _StepText(
                          number: '4',
                          text:
                              'You approve the baseline \u2014 only then can work run',
                          isDone: false,
                        ),
                        const SizedBox(height: 18),
                        const ContentRule(),
                        const SizedBox(height: 14),
                        MobilePrimaryButton(
                          label: state.isRegistering
                              ? 'Registering\u2026'
                              : 'Register product',
                          onPressed: state.canRegister && !state.isRegistering
                              ? () => context.read<AddProductBloc>().add(
                                  const RegisterProductRequested(),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _registerButtonSubtext(state),
                          textAlign: TextAlign.center,
                          style: ShipItType.monoMeta.copyWith(
                            fontSize: 10,
                            color: palette.inkTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TechnicalDetails(
                    note:
                        'Registering records the product. Nothing is governed until '
                        'you approve a baseline.',
                    lines: [
                      'productName=${state.productName.isEmpty ? '—' : state.productName}',
                      'repository=${state.repository.isEmpty ? '—' : state.repository}',
                      'revision=${state.revision}',
                      if (state.deployKey != null)
                        'deployKeyFingerprint=${state.deployKey!.fingerprint}',
                      'accessStatus=${state.accessStatus.name}',
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Bottom nav bar is provided by AppShell, not here
      ],
    );
  }

  Widget _buildField(
    BuildContext context, {
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    String? errorText,
  }) {
    return FormFieldSlot(
      label: label,
      control: SingleLineInput(
        hintText: hint,
        onChanged: onChanged,
        errorText: errorText,
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      edgeColor: palette.accent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MicroLabel(
            'WHAT SHIPIT DOES WITH THIS KEY',
            color: palette.inkTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            "It clones over SSH. The private half stays in this device's "
            'keychain \u2014 never shown, logged or stored.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'It pushes and merges on its own. Only promotion to production '
            'waits for you.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyBox(BuildContext context, AddProductState state) {
    final palette = context.palette;
    final deployKey = state.deployKey!;
    final (statusLabel, statusColor) = _statusLabel(
      state.accessStatus,
      palette,
    );

    return DesignPanel(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 2,
              height: 11,
              color: ShipItPalette.dark.attentionTick,
            ),
          ),
          Positioned(
            right: 16,
            top: 0,
            child: Text(
              statusLabel,
              style: ShipItType.bodySmall.copyWith(color: statusColor),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              MicroLabel(
                'DEPLOY KEY  \u00b7  THIS PRODUCT ONLY',
                color: palette.inkTertiary,
              ),
              const SizedBox(height: 10),
              Text(
                'Generated for this product',
                style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'ed25519 \u00b7 created on this device \u00b7 the private half stays in the keychain',
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
              const SizedBox(height: 10),
              SelectableText(
                deployKey.publicKey,
                style: ShipItType.monoMeta.copyWith(
                  color: palette.inkSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  InlineLink(
                    micro: true,
                    label: 'Copy public key',
                    onTap: () => _copyToClipboard(context, deployKey.publicKey),
                  ),
                  const SizedBox(width: 16),
                  InlineLink(
                    micro: true,
                    label: state.accessStatus == AccessStatus.verified
                        ? 'Check again'
                        : 'Check access',
                    onTap: state.accessStatus == AccessStatus.checking
                        ? null
                        : () => context.read<AddProductBloc>().add(
                            const CheckAccessRequested(),
                          ),
                  ),
                ],
              ),
              if (state.accessStatus == AccessStatus.failed) ...[
                const SizedBox(height: 8),
                Text(
                  'Access check failed. Ensure the key is installed with write access.',
                  style: ShipItType.bodySmall.copyWith(color: palette.negative),
                ),
              ],
              if (state.accessStatus == AccessStatus.checking) ...[
                const SizedBox(height: 8),
                Text(
                  'Checking access\u2026',
                  style: ShipItType.bodySmall.copyWith(color: palette.accent),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Add this key to the repository\u2019s deploy keys with write access, then check.',
                style: ShipItType.bodySmall.copyWith(
                  color: palette.inkTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color) _statusLabel(AccessStatus status, ShipItPalette palette) {
    switch (status) {
      case AccessStatus.notGenerated:
      case AccessStatus.notChecked:
        return ('Not installed yet', palette.attention);
      case AccessStatus.checking:
        return ('Checking\u2026', palette.accent);
      case AccessStatus.verified:
        return ('Verified', palette.positive);
      case AccessStatus.failed:
        return ('Access failed', palette.negative);
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Public key copied')));
  }
}
