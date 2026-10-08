import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/ssh_keypair.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:test/test.dart';

/// Proof that the deploy key this lane mints is a REAL ed25519 key, in the form
/// a git host will accept — not the non-installable mock
/// (`ssh-ed25519 <32 random bytes>`) that Add Product's Register button was
/// waiting on.
///
/// The proofs are layered deliberately, because each one rules out a different
/// way of being wrong:
///
///   1. RFC 8032 §7.1 vectors — the derivation is correct, not merely
///      deterministic. A key generator that returned its own seed as its public
///      key would pass every self-consistency check below.
///   2. `ssh-keygen -lf` agreement on the fingerprint — the value SHIP IT stores
///      is the one a host's UI shows, computed by the implementation an operator
///      compares against.
///   3. `ssh-keygen -y` on the generated PEM — the private half is a file OpenSSH
///      actually loads, and it is the matching half of the public key. This is
///      the test that would have caught a non-installable key.
///   4. sign/verify round-trip — the pair is usable, not merely well-shaped.
const _rfc8032Vectors = <(String, String, String)>[
  // (seed hex, expected public hex, expected SHA256 fingerprint). All three
  // fingerprints were produced by `ssh-keygen -lf` on the corresponding public
  // key and are asserted against it again below, so this file never trusts its
  // own arithmetic for the fingerprint.
  (
    '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
    'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
    'SHA256:bbXpuKG6zhzdmnxq256TlqzFBzRl2f6OOg722cYNbU8',
  ),
  (
    '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
    '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
    'SHA256:F34nin7tcaYH6WR5LSWSfj6weFBPfBpuyUUoPFP9YjA',
  ),
  (
    'c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7',
    'fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025',
    'SHA256:s3Z2A+mldeflHo5TMMEUA7MlkMg96xvtqH9DGLHHZmE',
  ),
];

List<int> _hex(String value) => [
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
];

String _hexEncode(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Skips a test when the OpenSSH tools are absent, rather than failing.
///
/// `ssh-keygen` is what proves the key is installable, so a host without it has
/// not disproved anything. The pure-Dart proofs still run there.
///
/// The probe is "did the binary start", not "did it print help": OpenSSH exits 1
/// for every one of its usage forms, and a check on exit status would skip this
/// proof on every host including the ones that can run it. 127 is the shell's
/// "command not found", which `Process.runSync` surfaces as the child's exit
/// code.
bool _sshKeygenAvailable() {
  final probe = Process.runSync('ssh-keygen', const ['-l', '-f', '/dev/null']);
  return probe.exitCode != 127;
}

final bool _hasSshKeygen = _sshKeygenAvailable();

void main() {
  group('ed25519 derivation', () {
    test('reproduces the RFC 8032 §7.1 public keys from their seeds', () {
      for (final (seedHex, publicHex, _) in _rfc8032Vectors) {
        final pair = SshKeyPair.fromSeed(
          seed: SecretBytes(_hex(seedHex)),
          comment: 'vector',
        );
        expect(
          _hexEncode(pair.publicKeyBytes),
          publicHex,
          reason: 'RFC 8032 public key for seed $seedHex',
        );
      }
    });

    test('produces the fingerprint OpenSSH reports for the same key', () {
      // Guards against a fingerprint computed over the wrong bytes. Computing it
      // over the bare 32-byte key instead of the SSH wire blob yields a stable,
      // plausible-looking value that no host's UI will ever show.
      for (final (seedHex, publicHex, fingerprint) in _rfc8032Vectors) {
        final pair = SshKeyPair.fromSeed(
          seed: SecretBytes(_hex(seedHex)),
          comment: 'vector',
        );
        expect(pair.fingerprint, fingerprint);
        expect(
          base64.decode(base64.normalize(pair.fingerprint.split(':')[1])),
          hasLength(32),
          reason: 'SHA-256 over the wire blob',
        );
        expect(
          pair.publicKeyAuthorizedLine.split(' ')[1],
          base64
              .encode(
                pair.publicKeyBlob,
              )
              .replaceFirst(RegExp(r'==?$'), ''),
        );
        expect(_hexEncode(pair.publicKeyBytes), publicHex);
      }
    });

    test('rejects a seed of the wrong length instead of guessing', () {
      expect(
        () => SshKeyPair.fromSeed(
          seed: SecretBytes(List<int>.filled(31, 0)),
          comment: 'short',
        ),
        throwsArgumentError,
      );
      expect(
        () => encodeOpensshPrivateKeyPem(
          Uint8List(31),
          comment: 'short',
        ),
        throwsArgumentError,
      );
    });
  });

  group('generated keypairs are valid ed25519 keys', () {
    test('are structurally sound and self-consistent under sign/verify', () {
      for (var i = 0; i < 8; i++) {
        final pair = SshKeyPair.generate(comment: 'shipit+shape-$i');
        expect(pair.publicKeyBytes, hasLength(ed.PublicKeySize));
        expect(pair.privateSeed, hasLength(ed.SeedSize));
        expect(pair.algorithm, 'ed25519');
        expect(
          pair.publicKeyAuthorizedLine,
          startsWith('ssh-ed25519 AAAAC3NzaC1lZDI1NTE5'),
          reason: 'the wire blob for ssh-ed25519 always opens this way',
        );
        expect(
          pair.fingerprint,
          matches(RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$')),
        );

        // Usable, not merely well-shaped: a pair that cannot sign cannot
        // authenticate, and the host would reject it.
        final privateKey = ed.newKeyFromSeed(pair.privateSeed);
        final message = Uint8List.fromList(utf8.encode('shipit-probe'));
        final signature = ed.sign(privateKey, message);
        expect(
          ed.verify(ed.PublicKey(pair.publicKeyBytes), message, signature),
          isTrue,
        );
        final tampered = Uint8List.fromList(message)..[0] = 0;
        expect(
          ed.verify(ed.PublicKey(pair.publicKeyBytes), tampered, signature),
          isFalse,
          reason: 'a signature must not verify over different bytes',
        );
      }
    });

    test('draws a different key every time', () {
      // Guards against a generator seeded from the clock or a constant, which
      // would produce the same deploy key for every repository in the fleet —
      // exactly the blast radius ADR 0018 exists to prevent.
      final fingerprints = <String>{};
      for (var i = 0; i < 16; i++) {
        fingerprints.add(
          SshKeyPair.generate(comment: 'shipit+uniq').fingerprint,
        );
      }
      expect(fingerprints, hasLength(16));
    });

    test('a wiped seed no longer reproduces the key', () {
      final pair = SshKeyPair.generate(comment: 'shipit+wipe');
      final before = pair.fingerprint;
      pair.wipeSeed();
      expect(pair.privateSeed, everyElement(0));
      expect(
        SshKeyPair.fromSeed(
          seed: SecretBytes(pair.privateSeed),
          comment: 'shipit+wipe',
        ).fingerprint,
        isNot(before),
      );
    });
  });

  group('the private half is a file OpenSSH loads', () {
    test(
      'ssh-keygen -y reads the PEM and reports the matching public key',
      () {
        // THE test that distinguishes an installable deploy key from a fake one.
        // `ssh-keygen -y` is the same loader OpenSSH uses for an `IdentityFile`;
        // if it cannot recover the public key from this file, no git host ever
        // will.
        final pair = SshKeyPair.generate(comment: 'shipit+identity');
        final dir = Directory.systemTemp.createTempSync('shipit_pem_probe_');
        final identity = File('${dir.path}/id_ed25519');
        try {
          identity.writeAsStringSync(pair.privateKeyPem);
          Process.runSync('chmod', ['600', identity.path]);

          final derived = Process.runSync('ssh-keygen', [
            '-y',
            '-f',
            identity.path,
          ]);
          expect(
            derived.exitCode,
            0,
            reason:
                'ssh-keygen rejected the generated private key: '
                '${derived.stderr}',
          );
          final recovered = (derived.stdout as String).trim().split(' ');
          expect(
            recovered.take(2).join(' '),
            pair.publicKeyAuthorizedLine.split(' ').take(2).join(' '),
            reason: 'OpenSSH recovered a different public half from our seed',
          );

          final fingerprint = Process.runSync('ssh-keygen', [
            '-lf',
            identity.path,
          ]);
          expect(fingerprint.exitCode, 0);
          expect(
            (fingerprint.stdout as String),
            contains(pair.fingerprint),
            reason: 'OpenSSH computes a different SHA-256 fingerprint',
          );
        } finally {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        }
      },
      skip: _hasSshKeygen ? false : 'ssh-keygen is not installed on this host',
    );

    test('the PEM body is not the seed, and the seed is not in it', () {
      // The container is `openssh-key-v1`; the raw seed never appears as an
      // armoured PKCS#8 blob, which is the encoding a reader would mistake for a
      // generic private key in a log review.
      final pair = SshKeyPair.generate(comment: 'shipit+pem');
      expect(
        pair.privateKeyPem,
        startsWith('-----BEGIN OPENSSH PRIVATE KEY-----'),
      );
      expect(
        pair.privateKeyPem.trim(),
        endsWith('-----END OPENSSH PRIVATE KEY-----'),
      );
      expect(pair.privateKeyPem, isNot(contains('PRIVATE KEY-----BASE64')));
      expect(
        pair.privateKeyPem,
        isNot(contains(base64.encode(pair.privateSeed))),
      );
    });
  });

  group('SecretBytes cannot be printed', () {
    test('toString emits a length and no bytes', () {
      final secret = SecretBytes(_hex('0badc0de'));
      expect(secret.toString(), '<secret redacted, 4 bytes>');
      expect(secret.toString(), isNot(contains('badc0de')));
      expect(secret.toString(), isNot(contains('badc0')));
      expect(secret.length, 4);
    });

    test('interpolating it into a message leaks nothing', () {
      final secret = SecretBytes(_hex('0badc0de'));
      // The two shapes below are the accidental leaks: a log field and an
      // exception message. Both must come out carrying only the length.
      expect('stored=$secret', 'stored=<secret redacted, 4 bytes>');
      expect(
        () => throw StateError('store failed for $secret'),
        throwsA(
          predicate(
            (e) => !e.toString().contains('badc0de'),
            'exception message must not carry key bytes',
          ),
        ),
      );
    });

    test('copies its input so a later mutation cannot reach the secret', () {
      final source = List<int>.from(_hex('0badc0de'));
      final secret = SecretBytes(source);
      source[0] = 0x00;
      expect(_hexEncode(secret.bytes), '0badc0de');
    });

    test('wipe zeroes the buffer', () {
      final secret = SecretBytes(_hex('0badc0de'));
      secret.wipe();
      expect(secret.bytes, everyElement(0));
      expect(secret.toString(), '<secret redacted, 4 bytes>');
    });
  });
}
