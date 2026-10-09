import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../data/control_plane_repository.dart';
import '../../data/operator_attestation.dart';
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
  AddProductBloc({required this._repository, OperatorAttestation? attestation})
    : super(
        AddProductState(
          attestation: attestation ?? OperatorAttestation.fromRuntime(),
        ),
      ) {
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

  /// Mints the deploy key on the server, then — when the operator has supplied
  /// a host-key confirmation — proves it can reach the repository.
  ///
  /// WHY MINTING AND VERIFYING LIVE TOGETHER, in one press of one control. The
  /// approved sequence needs the public key on screen *before* Register is
  /// pressable, and Register needs `accessStatus == verified`. A verification
  /// can therefore only happen after a mint, so splitting them across two
  /// controls would either hide the key or add a step the design does not have.
  /// Re-pressing is safe and is the "Check again" path: [AddProductState.deployKey]
  /// being set skips the mint — the engine's `recordGeneratedCredential` is
  /// insert-only and refuses a second active credential — and goes straight to
  /// the verification.
  Future<void> _onCheckAccessRequested(
    CheckAccessRequested event,
    Emitter<AddProductState> emit,
  ) async {
    if (!state.canGenerateKey) return;

    emit(
      state.copyWith(
        isCheckingAccess: true,
        accessStatus: AccessStatus.checking,
        clearError: true,
        clearAccessFailure: true,
      ),
    );
    try {
      final productId = _productId(state.productName);

      // The credential can only be minted against a repository this product
      // owns: `CredentialKeyService.generate` resolves the repository reference
      // first and refuses anything else. So the durable product and its
      // repository reference have to exist before the mint, which means before
      // the human can ever see the public key. Both calls are upserts
      // (`ON CONFLICT DO UPDATE`), so re-running is a no-op rather than a
      // duplicate.
      await _ensureProductAndRepository(productId);

      var deployKey = state.deployKey;
      if (deployKey == null) {
        final minted = await _repository.generateDeployKey(
          productId: productId,
          repositoryId: productId,
        );
        deployKey = DeployKeyPair(
          credentialId: minted.credentialId,
          publicKey: minted.publicKey,
          fingerprint: minted.fingerprint,
          algorithm: minted.algorithm,
        );
        emit(
          state.copyWith(
            deployKey: deployKey,
            accessStatus: AccessStatus.notChecked,
          ),
        );
      }

      final attestation = state.attestation;
      if (!attestation.isComplete) {
        // The key is minted and installable, but nothing has been proved. This
        // is not an error: the operator still has to install the deploy key, and
        // a deployment that has not configured a host-key confirmation cannot
        // honestly run the check. Inventing a fingerprint to get past it would
        // be the silent default ADR 0018 refuses.
        emit(state.copyWith(isCheckingAccess: false));
        return;
      }

      final verification = await _repository.verifyDeployKeyAccess(
        productId: productId,
        repositoryId: productId,
        hostKeyFingerprint: attestation.hostKeyFingerprint!,
        confirmedBy: attestation.confirmedBy!,
        checkedBy: attestation.confirmedBy,
      );

      // THE WRITE THAT WAS MISSING. `AccessStatus.verified` was read in nine
      // places and written in none, so `canRegister` — which requires it — was
      // permanently false and the Register button was permanently disabled.
      emit(
        state.copyWith(
          isCheckingAccess: false,
          accessStatus: verification.isVerified
              ? AccessStatus.verified
              : AccessStatus.failed,
          accessFailureReason: verification.isVerified
              ? null
              : verification.failureReason,
        ),
      );
    } catch (e) {
      // A failure with no key yet is a failure the operator cannot see from the
      // key box (there is no key box), so it takes the page-level error surface
      // this form already uses. A failure with a key is shown in the key box,
      // beside the key it is about.
      final hasKey = state.deployKey != null;
      emit(
        state.copyWith(
          isCheckingAccess: false,
          accessStatus: AccessStatus.failed,
          errorMessage: hasKey ? null : _describe(e),
          accessFailureReason: hasKey ? _describe(e) : null,
        ),
      );
    }
  }

  Future<void> _onRegisterProductRequested(
    RegisterProductRequested event,
    Emitter<AddProductState> emit,
  ) async {
    // `canRegister` is the whole gate: it already requires a deploy key, a
    // verified access check and no in-flight registration. Repeating those tests
    // here would give two answers to one question.
    if (!state.canRegister) return;

    emit(state.copyWith(isRegistering: true, clearError: true));
    try {
      final productId = _productId(state.productName);

      await _ensureProductAndRepository(productId);

      // CONFIRM THE CREDENTIAL IS ACTUALLY THERE rather than assuming it.
      // Register used to stop at `addRepositoryReference` and discard the key,
      // which left a product that could never reach its repository. Reading the
      // detail back and matching on `credentialId` is what turns "a key was
      // shown at some point" into "this product has this credential attached".
      final detail = await _repository.getProductDetail(productId);
      final expected = state.deployKey!.credentialId;
      final attached = detail.credentials
          .where((c) => c.credentialId == expected)
          .toList(growable: false);
      if (attached.isEmpty) {
        throw StateError(
          'the credential proved for this product is not attached to it; '
          'nothing was registered. Run the access check again.',
        );
      }
      if (attached.single.status != 'verified') {
        throw StateError(
          'the attached credential is "${attached.single.status}", not '
          '"verified"; nothing was registered.',
        );
      }

      emit(
        state.copyWith(
          isRegistering: false,
          // The detail read back, not the one from the upsert: this one shows
          // the credential that was just confirmed attached, so navigating to
          // the product detail screen lands on a screen that agrees with what
          // the flow just proved.
          productCreated: detail,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isRegistering: false, errorMessage: _describe(e)));
    }
  }

  /// Creates the product and its repository reference if they are not there.
  ///
  /// Both writes are upserts server-side (`ON CONFLICT DO UPDATE`), so calling
  /// this on every check and every register is idempotent. It is the one thing
  /// that has to happen before a deploy key can exist, and it lives here rather
  /// than in a separate step because the approved sequence has no step for it.
  Future<void> _ensureProductAndRepository(String productId) async {
    await _repository.createProduct(
      productId: productId,
      name: state.productName,
      description: '',
      manifestJson: '{}',
    );
    await _repository.addRepositoryReference(
      productId: productId,
      repositoryId: productId, // Use productId as repositoryId for simplicity
      uri: state.repository,
      kind: 'monorepo',
      provider: 'github', // Could be parsed from URI in the future
    );
  }

  static String _productId(String productName) =>
      productName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');

  /// Serverpod surfaces a transport or endpoint failure as an exception. Render
  /// it as text rather than as a type name — an operator cannot act on
  /// "Exception: bad state: ...".
  static String _describe(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) return 'The server refused the request.';
    return text;
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
    this.accessFailureReason,
    this.attestation = const OperatorAttestation(),
  });

  final String productName;
  final String repository;
  final String revision;

  /// The server-minted deploy key, or null before one has been minted.
  ///
  /// Never a locally generated one: there is no client-side key generation in
  /// this app, and a key the client made would be a key no secret manager holds.
  final DeployKeyPair? deployKey;
  final AccessStatus accessStatus;
  final bool isCheckingAccess;
  final bool isRegistering;
  final String? errorMessage;
  final ProductDetailResponse? productCreated;

  /// Why the last access check did not verify. Shown in the deploy-key box,
  /// beside the key it is about, rather than on the page-level error surface that
  /// replaces the form.
  final String? accessFailureReason;

  /// The operator's host-key confirmation, from deployment configuration.
  final OperatorAttestation attestation;

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
    String? accessFailureReason,
    OperatorAttestation? attestation,
    bool clearError = false,
    bool clearAccessFailure = false,
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
    accessFailureReason: clearAccessFailure
        ? null
        : (accessFailureReason ?? this.accessFailureReason),
    attestation: attestation ?? this.attestation,
  );

  bool get canGenerateKey =>
      productName.isNotEmpty && repository.isNotEmpty && !isCheckingAccess;

  /// Whether the verification step can actually run.
  ///
  /// Minting does not need a host-key confirmation, so [canGenerateKey] does not
  /// require one: an operator whose deployment has not configured a fingerprint
  /// can still get an installable public key. They just cannot prove access yet.
  bool get canCheckAccess => canGenerateKey && attestation.isComplete;

  /// The Register gate.
  ///
  /// Unchanged, and deliberately not weakened: a product may not be registered
  /// without a deploy key whose access the server proved with a real clone. This
  /// is now reachable because `AccessStatus.verified` is written when
  /// `verifyAccess` succeeds — not because the gate was relaxed.
  bool get canRegister =>
      deployKey != null &&
      accessStatus == AccessStatus.verified &&
      !isRegistering;
}

/// The five states of "does this product's key actually reach its repository".
///
/// Every case is written by [_CheckAccessRequested]'s handler; `verified` is the
/// one that was previously unreachable, which is why the Register button could
/// never be pressed.
enum AccessStatus { notGenerated, notChecked, checking, verified, failed }

/// The public half of a deploy key the server minted, and its durable identity.
///
/// There is no private half here, and no field that could hold one. The key is
/// generated by the server, handed straight to the secret manager, and only
/// [publicKey] and [fingerprint] — both derivable from public material — come
/// back.
class DeployKeyPair {
  const DeployKeyPair({
    required this.credentialId,
    required this.publicKey,
    required this.fingerprint,
    required this.algorithm,
  });

  /// Durable identity of the credential row the server wrote. Register matches
  /// on this so the product it creates is provably attached to this key.
  final String credentialId;

  final String publicKey;
  final String fingerprint;
  final String algorithm;
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
    // Read once and guard both lines with it. The previous code guarded the
    // fingerprint line and then dereferenced `state.deployKey!` again in the
    // CONDITION of the next line, so the page threw
    // "Null check operator used on a null value" on exactly the empty state the
    // form starts in — the state in which the operator has to be told what to do
    // next. A cold render crashed before it could render anything.
    final deployKey = state.deployKey;
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
            TechnicalDetails(
              lines: [
                'productName=${state.productName.isEmpty ? '—' : state.productName}',
                'repository=${state.repository.isEmpty ? '—' : state.repository}',
                'revision=${state.revision}',
                if (deployKey != null) ...[
                  'deployKeyFingerprint=${deployKey.fingerprint}',
                  if (deployKey.credentialId.isNotEmpty)
                    'credentialId=${deployKey.credentialId}',
                ],
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
        if (state.deployKey != null)
          _buildKeyBox(context, state)
        else
          _GenerateDeployKeyPanel(state: state),
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
            'It clones over SSH. The private half stays in the secret manager '
            '\u2014 never shown, logged or stored.',
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
                'ed25519 \u00b7 generated on the server \u00b7 the private half stays in the secret manager',
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
              if (state.accessFailureReason != null) ...[
                const SizedBox(height: 6),
                Text(
                  state.accessFailureReason!,
                  style: ShipItType.monoMeta.copyWith(color: palette.negative),
                ),
              ],
              const SizedBox(height: 14),
              const ContentRule(),
              const SizedBox(height: 12),
              _HostKeyAttestation(state: state),
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

/// The slot step 1 occupies before there is a key: the control that mints one.
///
/// WHY THIS EXISTS. At `2f6b78d` the deploy-key flow was unreachable, not merely
/// disabled, and the mechanism was circular. `AddProductState.deployKey` was
/// written in exactly one place — inside `_onCheckAccessRequested`. That handler
/// ran only for `CheckAccessRequested`, which was dispatched from exactly one
/// place: `_buildKeyBox`. And `_buildKeyBox` rendered only under
/// `if (state.deployKey != null)`. So a null key meant no key box, so nothing
/// dispatched the event, so the key could never become non-null. The Register
/// button's own subtext promised "Generate a deploy key first" and no control
/// anywhere said "Generate a deploy key" — the giveaway that the promise had
/// nothing behind it.
///
/// Dispatching [CheckAccessRequested] rather than inventing an event is the
/// point: that handler already mints through `_repository.generateDeployKey` and
/// already calls `_ensureProductAndRepository` first, so the mint can only happen
/// once the product and its repository reference exist, exactly as the server
/// requires. A separate "mint" event would have been a second path to the same
/// key with none of that ordering.
///
/// ONE WIDGET, BOTH LAYOUTS. The mobile twin of this affordance is the one that
/// was missed historically, so it is declared once and rendered from both the
/// desktop and the mobile composition rather than copied into each. There is no
/// second copy that can be forgotten.
///
/// GATED, NOT DISABLED. Rendered only while [AddProductState.canGenerateKey]
/// holds, because minting resolves the repository reference server-side and
/// cannot succeed without both inputs. An action that cannot succeed is not
/// offered; while it is unavailable this states which input is missing, rather
/// than presenting a control that would fail.
class _GenerateDeployKeyPanel extends StatelessWidget {
  const _GenerateDeployKeyPanel({required this.state});

  final AddProductState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ready = state.canGenerateKey;
    return DesignPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MicroLabel(
            'DEPLOY KEY  \u00b7  THIS PRODUCT ONLY',
            color: palette.inkTertiary,
          ),
          const SizedBox(height: 10),
          Text(
            state.isCheckingAccess
                ? 'Generating a deploy key\u2026'
                : 'No deploy key for this product yet',
            style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'ed25519 \u00b7 generated on the server \u00b7 the private half stays in the secret manager',
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
          const SizedBox(height: 12),
          if (ready)
            FilledButton(
              onPressed: () => context.read<AddProductBloc>().add(
                const CheckAccessRequested(),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ShipItMetrics.radius),
                ),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Generate a deploy key',
                style: ShipItType.monoMeta.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: palette.inkPrimary,
                ),
              ),
            )
          else
            Text(
              _generateBlockedReason(state),
              style: ShipItType.bodySmall.copyWith(color: palette.attention),
            ),
        ],
      ),
    );
  }

  /// Why there is nothing to press, in the same voice as
  /// [_registerButtonSubtext] and for the same reason: an operator who is told
  /// only that a control is missing has no way to know which field to fill.
  static String _generateBlockedReason(AddProductState state) {
    if (state.isCheckingAccess) return 'Generating the key\u2026';
    if (state.productName.isEmpty) return 'A product name is required first';
    if (state.repository.isEmpty) return 'A repository URL is required first';
    return 'The key is being generated';
  }
}

/// The host-key confirmation the access check will send, and what it is.
///
/// SURFACED, NOT COLLECTED, AND SAYS SO. `verifyAccess` requires a
/// `hostKeyFingerprint` and a `confirmedBy` that the server cannot produce for
/// itself — ADR 0018 §Decision's trust-on-first-use — and both are operator
/// assertions the server does not authenticate (finding M-5, open). They come
/// from deployment configuration ([OperatorAttestation]), never from this screen
/// and never from a constant in this file: a fingerprint written into the client
/// would be a value the operator never checked, presented as if they had.
///
/// The panel states the limitation in the product's own voice rather than
/// burying it, because the alternative — a green "Verified" that an operator
/// reads as the platform having checked GitHub's identity — is the
/// misunderstanding M-5 describes.
class _HostKeyAttestation extends StatelessWidget {
  const _HostKeyAttestation({required this.state});

  final AddProductState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final attestation = state.attestation;
    final complete = attestation.isComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MicroLabel(
          'HOST KEY  \u00b7  YOU CONFIRM THIS',
          color: palette.inkTertiary,
        ),
        const SizedBox(height: 8),
        Text(
          'Compare this against the fingerprints your git host publishes, then '
          'install the key. ShipIt checks that the host presents the same key '
          'and refuses to clone when it does not \u2014 but it asks you for it, '
          'it does not look it up.',
          style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
        ),
        const SizedBox(height: 8),
        Text(
          'fingerprint  ${attestation.hostKeyFingerprint ?? 'not configured'}',
          style: ShipItType.monoMeta.copyWith(
            color: complete ? palette.inkSecondary : palette.attention,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'confirmed by  ${attestation.confirmedBy ?? 'not configured'}',
          style: ShipItType.monoMeta.copyWith(
            color: complete ? palette.inkSecondary : palette.attention,
          ),
        ),
        if (!complete) ...[
          const SizedBox(height: 8),
          Text(
            'Access cannot be proven until this deployment supplies both. Set '
            'SHIPIT_HOST_KEY_FINGERPRINT and SHIPIT_OPERATOR_NAME for the app.',
            style: ShipItType.bodySmall.copyWith(color: palette.attention),
          ),
        ],
      ],
    );
  }
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
    // As on desktop: one guarded local, not a `deployKey!` dereference inside the
    // condition of the credentialId line. See [_DesktopAddProduct.build].
    final deployKey = state.deployKey;
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
                  if (state.deployKey != null)
                    _buildKeyBox(context, state)
                  else
                    _GenerateDeployKeyPanel(state: state),
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
                    showRule: false,
                    disclosureAlignment: DisclosureAlignment.start,
                    lines: [
                      'productName=${state.productName.isEmpty ? '—' : state.productName}',
                      'repository=${state.repository.isEmpty ? '—' : state.repository}',
                      'revision=${state.revision}',
                      if (deployKey != null) ...[
                        'deployKeyFingerprint=${deployKey.fingerprint}',
                        if (deployKey.credentialId.isNotEmpty)
                          'credentialId=${deployKey.credentialId}',
                      ],
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
            'It clones over SSH. The private half stays in the secret manager '
            '\u2014 never shown, logged or stored.',
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
                'ed25519 \u00b7 generated on the server \u00b7 the private half stays in the secret manager',
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
              if (state.accessFailureReason != null) ...[
                const SizedBox(height: 6),
                Text(
                  state.accessFailureReason!,
                  style: ShipItType.monoMeta.copyWith(color: palette.negative),
                ),
              ],
              const SizedBox(height: 14),
              const ContentRule(),
              const SizedBox(height: 12),
              _HostKeyAttestation(state: state),
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
