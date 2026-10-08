import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import 'secret_material.dart';

/// SSH wire-format name of the only key type ADR 0018 allows.
const String kSshEd25519 = 'ssh-ed25519';

/// Value recorded in `RepositoryCredential.algorithm`.
const String kAlgorithmEd25519 = 'ed25519';

/// OpenSSH's private-key armour header, as bytes.
const List<int> _kOpensshPemHeader = [
  45, 45, 45, 45, 45, // -----
  66, 69, 71, 73, 78, // BEGIN
  32, // space
  79, 80, 69, 78, 83, 83, 72, // OPENSSH
  32, // space
  80, 82, 73, 86, 65, 84, 69, // PRIVATE
  32, // space
  75, 69, 89, // KEY
  45, 45, 45, 45, 45, // -----
];

/// OpenSSH's private-key armour footer, as bytes.
const List<int> _kOpensshPemFooter = [
  45, 45, 45, 45, 45, // -----
  69, 78, 68, // END
  32, // space
  79, 80, 69, 78, 83, 83, 72, // OPENSSH
  32, // space
  80, 82, 73, 86, 65, 84, 69, // PRIVATE
  32, // space
  75, 69, 89, // KEY
  45, 45, 45, 45, 45, // -----
];

/// Magic prefix of the `openssh-key-v1` private key container
/// (`PROTOCOL.key` in the OpenSSH source tree), including its NUL terminator.
const List<int> _kOpensshKeyV1Magic = [
  111, // o
  112, // p
  101, // e
  110, // n
  115, // s
  115, // s
  104, // h
  45, // -
  107, // k
  101, // e
  121, // y
  45, // -
  118, // v
  49, // 1
  0, // \0
];

/// Block size the `none` cipher reports, which is what the padding rule in
/// `PROTOCOL.key` is defined against.
const int _kNoneCipherBlockSize = 8;

/// One repository deploy keypair, generated server-side (ADR 0018 §A2/A3).
///
/// This type exists so that no call site has to choose between "the private half"
/// and "the public half" by discipline. The private half is reachable through
/// exactly two members, and both are confined:
///
///   * [privateSeed] is a [SecretBytes], whose only textual projection is a length.
///     A `log('$pair.privateSeed')` or an `'$seed'` in an exception message
///     therefore emits `<secret redacted, 32 bytes>`, exactly as if the raw
///     buffer had been wrapped at construction. There is **no** public accessor
///     that returns the seed as a `Uint8List` or a `String`.
///   * [privateKeyPemBytes] is the OpenSSH container, as bytes. There is
///     **no** `String` rendering of the private half on this type at all — see
///     [encodeOpensshPrivateKeyPemBytes] for why one is no longer needed, and
///     note that the previous implementation's `String get privateKeyPem` was the
///     exact hole this doc used to deny existed.
///
/// [publicKey], [publicKeyBlob], [publicKeyAuthorizedLine] and [fingerprint] are
/// the entire set of things that may leave the process, be logged, or be written
/// to the durable record.
///
/// The type is deliberately NOT `toJson`-able. A credential row is built from
/// [publicKeyAuthorizedLine] and [fingerprint] only — there is no accessor that
/// yields a private half as text, so there is nothing to paste into a column, a
/// log field or an exception message by accident.
class SshKeyPair {
  // Split into a factory plus a generative constructor so the seed can be a
  // *private* initializing formal (`this._privateSeed`) while the call sites read
  // `privateSeed:`. Writing `required this.privateSeed` instead would publish the
  // seed as public API, which is the B-2 defect, and `prefer_initializing_formals`
  // is right to complain — hence the two-step rather than an ignore.
  factory SshKeyPair._({
    required SecretBytes privateSeed,
    required Uint8List publicKeyBytes,
    required String comment,
  }) => SshKeyPair._custody(privateSeed, publicKeyBytes, comment);

  // Positional because a *named* parameter cannot be `_privateSeed`: Dart takes
  // the public part of the name, so naming it would publish the field.
  SshKeyPair._custody(this._privateSeed, this.publicKeyBytes, this.comment);

  /// Generates a fresh ed25519 keypair from the platform CSPRNG.
  ///
  /// Entropy comes from `ed25519_edwards`, which fills the seed with secure
  /// random bytes (`fillBytesWithSecureRandomNumbers`); no `Random()` default
  /// seed is ever involved. [comment] is the human-readable label OpenSSH shows
  /// in `known_hosts`-adjacent listings — it is operator-visible metadata, never
  /// key material.
  factory SshKeyPair.generate({required String comment}) {
    final pair = ed.generateKey();
    return SshKeyPair._(
      // `ed.seed` narrows the 64-byte private key to the 32-byte RFC 8032 seed.
      privateSeed: SecretBytes(ed.seed(pair.privateKey)),
      publicKeyBytes: Uint8List.fromList(pair.publicKey.bytes),
      comment: comment,
    );
  }

  /// Rebuilds a keypair from a seed recovered from a secret manager.
  ///
  /// The public half is **recomputed from the seed**, never trusted from
  /// alongside it: a secret store that returned a mismatched public half would
  /// otherwise produce an identity file the operator's deploy key does not match,
  /// and the failure would surface as an unexplained auth rejection at the host
  /// rather than as a corrupt store.
  factory SshKeyPair.fromSeed({
    required SecretBytes seed,
    required String comment,
  }) {
    if (seed.length != ed.SeedSize) {
      // Length only. `seed`'s own toString is redacted, and interpolating it
      // here would be redundant, but the rule is worth stating: this message
      // must never gain a `${seed.bytes}`.
      throw ArgumentError.value(
        seed.length,
        'seed',
        'an ed25519 seed is ${ed.SeedSize} bytes',
      );
    }
    final privateKey = ed.newKeyFromSeed(seed.bytes);
    return SshKeyPair._(
      // A fresh wrapper, so wiping or mutating the caller's `SecretBytes` after
      // this call cannot reach into the pair.
      privateSeed: SecretBytes(seed.bytes),
      publicKeyBytes: Uint8List.fromList(privateKey.bytes.sublist(32, 64)),
      comment: comment,
    );
  }

  /// The seed, wrapped. Secret.
  ///
  /// A [SecretBytes] rather than a bare `Uint8List` because the wrapping is the
  /// whole point: a public `Uint8List` is one `log('$pair')`-adjacent mistake, or
  /// one `jsonEncode` of the pair, away from being in a session log that Postgres
  /// persists. Handing callers the wrapper keeps the guarantee at the type level
  /// rather than the review level, and makes reaching the raw bytes an explicit,
  /// greppable `.bytes` at the three sites that genuinely need them (the codec,
  /// the identity-file writer, and a test asserting the container round-trips).
  ///
  /// The wrapper **copies** its input, so the seed this pair was built from is
  /// not aliased by a caller who keeps it.
  SecretBytes get privateSeed => _privateSeed;

  final SecretBytes _privateSeed;

  /// The 32-byte ed25519 public key. Not secret.
  final Uint8List publicKeyBytes;

  /// Operator-visible label, e.g. `shipit+repo-1`. Not secret.
  final String comment;

  /// `ed25519`, as recorded in `RepositoryCredential.algorithm`.
  String get algorithm => kAlgorithmEd25519;

  /// SSH wire-format public key blob: `string("ssh-ed25519") || string(pub)`.
  ///
  /// This is what OpenSSH hashes for a fingerprint and what the host parses
  /// after the algorithm name on an authorized-keys line, so it is the single
  /// canonical serialisation everything else is derived from.
  Uint8List get publicKeyBlob {
    final blob = BytesBuilder(copy: false);
    blob.add(_sshString(utf8.encode(kSshEd25519)));
    blob.add(_sshString(publicKeyBytes));
    return blob.takeBytes();
  }

  /// `SHA256:<base64, unpadded>` — the fingerprint GitHub and GitLab display
  /// beside a deploy key, and the value the domain stores so an operator can
  /// confirm they installed the right half.
  ///
  /// Computed over [publicKeyBlob], not over the bare 32 bytes: the wire blob is
  /// what `ssh-keygen -lf` hashes, so hashing anything else would produce a
  /// fingerprint the host's UI never shows.
  String get fingerprint {
    final digest = crypto.sha256.convert(publicKeyBlob).bytes;
    return 'SHA256:${base64.encode(digest).replaceAll('=', '')}';
  }

  /// `ssh-ed25519 <base64 blob> <comment>` — the authorized-keys line the
  /// operator installs as a deploy key. Public: ADR 0018 explicitly surfaces it.
  String get publicKeyAuthorizedLine =>
      '$kSshEd25519 ${base64.encode(publicKeyBlob)} $comment';

  /// The private half as an OpenSSH `openssh-key-v1` private key, PEM-armoured,
  /// AS BYTES. Secret.
  ///
  /// Why a container at all, rather than handing a raw seed to the identity
  /// file: OpenSSH does not read raw seeds. Its loader requires the
  /// `openssh-key-v1` structure (`PROTOCOL.key`), so this is the only shape
  /// `IdentityFile` accepts. See [encodeOpensshPrivateKeyPemBytes].
  ///
  /// WHY THIS IS THE ONLY ACCESSOR, AND WHY IT IS BYTES. The previous
  /// implementation also exposed `String get privateKeyPem`, while this class's
  /// own documentation claimed the type "deliberately holds no `String`
  /// rendering of the secret" — a doc asserting the negation of the code, which
  /// is worse than no doc because a future reader trusts it. The `String` is now
  /// gone at the root rather than confined at the call site: PEM is
  /// base64-armoured, and base64 of arbitrary bytes is ASCII, so the whole
  /// armouring can be produced directly as bytes and no `String` of key material
  /// is ever constructed — not here, not in the test that hands the file to
  /// `ssh-keygen`, and not in the intermediate frame.
  Uint8List get privateKeyPemBytes =>
      encodeOpensshPrivateKeyPemBytes(_privateSeed.bytes, comment: comment);

  /// Wipes the seed. See [SecretBytes.wipe] for what this does and does not
  /// promise.
  void wipeSeed() => _privateSeed.wipe();

  @override
  String toString() =>
      'SshKeyPair(ed25519, fingerprint: $fingerprint, comment: $comment)';
}

/// Serialises an ed25519 seed as an unencrypted `openssh-key-v1` private key,
/// PEM-armoured, **as bytes**.
///
/// NO `String` OF KEY MATERIAL IS EVER BUILT. That is the point of the return
/// type: PEM is base64 text, so the obvious implementation ends in a `String`,
/// and a `String` is the one projection that is trivially loggable,
/// interpolatable into an exception message, and passable to anything taking
/// `Object`. Base64 of these bytes is ASCII by construction, so the armouring is
/// emitted as bytes directly and the intermediate textual form does not exist at
/// any point in this function.
///
/// THE FORMAT, and why this is hand-written rather than pulled from a package:
/// `openssh-key-v1` is a frozen, publicly documented container
/// (`PROTOCOL.key` §"Private key format" in the OpenSSH source tree). It is
/// *not* PKCS#8, and no general-purpose Dart package emits it — so the
/// alternatives were to add a dependency that does, or to shell out to
/// `ssh-keygen` for generation. Hand-writing sixty lines of a documented
/// container beats both: no new transitive surface, and the generation itself
/// stays in Dart where the redaction discipline of [SecretBytes] applies.
///
/// THE CIPHER IS `none`, which is a deliberate, bounded decision:
///
///   * `ssh-keygen -t ed25519 -N ''` — the obvious existing way to get a usable
///     private key — emits exactly this: I decoded one and confirmed
///     `ciphername: "none"`, `kdfname: "none"`, empty kdfoptions. OpenSSH
///     therefore both writes and reads the `none` cipher, so a file produced
///     here is loadable by the same implementation that loads its own.
///   * `aes256-ctr` + `bcrypt` would mean implementing bcrypt-pbkdf. That is
///     ~150 lines of password KDF whose *only* purpose here would be to
///     obfuscate a file that already exists on disk for a few milliseconds,
///     inside a 0700 directory, and is removed in a `finally`.
///
/// The plaintext-in-a-0600-file property is therefore explicit and reviewed
/// rather than incidental: the caller owns that obligation, and
/// [RepositoryAccessVerifier] discharges it.
Uint8List encodeOpensshPrivateKeyPemBytes(
  Uint8List seed, {
  required String comment,
}) {
  if (seed.length != ed.SeedSize) {
    throw ArgumentError.value(
      seed.length,
      'seed',
      'an ed25519 seed is ${ed.SeedSize} bytes',
    );
  }
  final privateKey = ed.newKeyFromSeed(seed);
  final publicKey = Uint8List.fromList(privateKey.bytes.sublist(32, 64));
  final publicBlob = SshKeyPair._(
    privateSeed: SecretBytes(Uint8List.fromList(seed)),
    publicKeyBytes: publicKey,
    comment: comment,
  ).publicKeyBlob;

  // `check1 == check2` is OpenSSH's integrity check for an unencrypted key: a
  // decoder that has the wrong passphrase, or is reading plaintext where it
  // expected ciphertext, sees the two words disagree. Random, as `ssh-keygen`
  // writes it, so it is not a fixed vector.
  final random = Random.secure();
  final check = random.nextInt(1 << 32);

  final plaintext = BytesBuilder(copy: false);
  plaintext
    ..add(_uint32(check))
    ..add(_uint32(check))
    ..add(_sshString(utf8.encode(kSshEd25519)))
    ..add(_sshString(publicKey))
    // OpenSSH stores `seed || publicKey` as the private value for ed25519; the
    // trailing half is redundant by construction and is what makes the file
    // self-checking for a decoder that already knows the algorithm.
    ..add(_sshString(privateKey.bytes))
    ..add(_sshString(utf8.encode(comment)));

  final unpadded = plaintext.takeBytes();
  final body = BytesBuilder(copy: false)
    ..add(unpadded)
    ..add(_opensshPadding(unpadded.length));
  final encrypted = body.takeBytes();

  final container = BytesBuilder(copy: false)
    ..add(_kOpensshKeyV1Magic)
    ..add(_sshString(const [110, 111, 110, 101])) // ciphername "none"
    ..add(_sshString(const [110, 111, 110, 101])) // kdfname    "none"
    ..add(_sshString(const <int>[])) // kdfoptions ""
    ..add(_uint32(1)) // number of keys
    ..add(_sshString(publicBlob))
    ..add(_sshString(encrypted));

  return _pemArmour(container.takeBytes());
}

/// PEM body at the 70-column wrapping `ssh-keygen` emits, as bytes.
///
/// Built with `base64.encode` into a byte buffer. `base64.encode` itself
/// returns a `String`, but the string it returns is base64 — pure ASCII that
/// contains no byte of the key that is not already in [der] — and it is dropped
/// on the next line. That is the distinction this function exists to preserve: a
/// `String` of *armoured* bytes is not a `String` of the secret, whereas the
/// previous `_pemWrap` returned the whole armoured document as a `String` and the
/// caller's `String get privateKeyPem` handed that document to anyone who asked.
Uint8List _pemArmour(Uint8List der) {
  final encoded = base64.encode(der);
  // 70 columns, exactly as `ssh-keygen` wraps; every line ends with a newline so
  // the footer is separated by LF rather than by a CRLF this code never writes.
  const lf = 0x0a;
  final out = BytesBuilder(copy: false)
    ..add(_kOpensshPemHeader)
    ..add([lf]);
  for (var offset = 0; offset < encoded.length; offset += 70) {
    out
      ..add(
        encoded.substring(offset, min(offset + 70, encoded.length)).codeUnits,
      )
      ..add([lf]);
  }
  out
    ..add(_kOpensshPemFooter)
    ..add([lf]);
  return out.takeBytes();
}

/// Padding bytes `PROTOCOL.key` defines: the integers 1, 2, 3, … appended until
/// the section length is a multiple of the cipher's block size.
Uint8List _opensshPadding(int currentLength) {
  final needed =
      (_kNoneCipherBlockSize - (currentLength % _kNoneCipherBlockSize)) %
      _kNoneCipherBlockSize;
  return Uint8List.fromList(List<int>.generate(needed, (i) => i + 1));
}

/// SSH `string`: a 32-bit big-endian length followed by the bytes.
Uint8List _sshString(List<int> value) {
  final builder = BytesBuilder(copy: false)
    ..add(_uint32(value.length))
    ..add(value);
  return builder.takeBytes();
}

/// Big-endian 32-bit unsigned integer.
Uint8List _uint32(int value) => Uint8List(4)
  ..[0] = (value >> 24) & 0xff
  ..[1] = (value >> 16) & 0xff
  ..[2] = (value >> 8) & 0xff
  ..[3] = value & 0xff;
