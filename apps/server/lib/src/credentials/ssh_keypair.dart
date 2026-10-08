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
/// and "the public half" by discipline. [privateSeed] and [privateKeyPem] are the
/// secret; [publicKey], [publicKeyBlob], [publicKeyAuthorizedLine] and
/// [fingerprint] are the entire set of things that may leave the process, be
/// logged, or be written to the durable record.
///
/// The type is deliberately NOT `toJson`-able and deliberately holds no
/// `String` rendering of the secret. A credential row is built from
/// [publicKeyAuthorizedLine] and [fingerprint] only — there is no accessor that
/// yields a private half as text, so there is nothing to paste into a column by
/// accident.
class SshKeyPair {
  SshKeyPair._({
    required this.privateSeed,
    required this.publicKeyBytes,
    required this.comment,
  });

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
      privateSeed: ed.seed(pair.privateKey),
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
      privateSeed: Uint8List.fromList(seed.bytes),
      publicKeyBytes: Uint8List.fromList(privateKey.bytes.sublist(32, 64)),
      comment: comment,
    );
  }

  /// The 32-byte RFC 8032 seed. Secret.
  final Uint8List privateSeed;

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

  /// The private half as an OpenSSH `openssh-key-v1` private key, PEM-armoured.
  ///
  /// Why a container at all, rather than handing a raw seed to the identity
  /// file: OpenSSH does not read raw seeds. Its loader requires the
  /// `openssh-key-v1` structure (`PROTOCOL.key`), so this is the only shape
  /// `IdentityFile` accepts. See [encodeOpensshPrivateKeyPem].
  String get privateKeyPem =>
      encodeOpensshPrivateKeyPem(privateSeed, comment: comment);

  /// [privateKeyPem] as bytes, for handing straight to a secret provider or an
  /// identity-file writer.
  ///
  /// Preferred over `SecretBytes(utf8.encode(pair.privateKeyPem))` at call
  /// sites because it keeps the PEM text in one frame that is discarded on
  /// return. The encoding itself is unavoidably textual — PEM is base64 — so
  /// one short-lived `String` of key material exists per call regardless; this
  /// only makes sure it is as short-lived as it can be.
  Uint8List get privateKeyPemBytes => Uint8List.fromList(
    encodeOpensshPrivateKeyPem(privateSeed, comment: comment).codeUnits,
  );

  /// Wipes the seed. See [SecretBytes.wipe] for what this does and does not
  /// promise.
  void wipeSeed() => privateSeed.fillRange(0, privateSeed.length, 0);

  @override
  String toString() =>
      'SshKeyPair(ed25519, fingerprint: $fingerprint, comment: $comment)';
}

/// Serialises an ed25519 seed as an unencrypted `openssh-key-v1` private key.
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
String encodeOpensshPrivateKeyPem(Uint8List seed, {required String comment}) {
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
    privateSeed: seed,
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

  return _pemWrap(container.takeBytes());
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

/// PEM body at the 70-column wrapping `ssh-keygen` emits.
String _pemWrap(Uint8List der) {
  const header = '-----BEGIN OPENSSH PRIVATE KEY-----';
  const footer = '-----END OPENSSH PRIVATE KEY-----';
  final encoded = base64.encode(der);
  final lines = <String>[header];
  for (var offset = 0; offset < encoded.length; offset += 70) {
    lines.add(encoded.substring(offset, min(offset + 70, encoded.length)));
  }
  lines.add(footer);
  return '${lines.join('\n')}\n';
}
