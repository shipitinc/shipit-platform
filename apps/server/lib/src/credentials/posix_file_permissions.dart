import 'dart:io';

import 'secretless_error.dart';

/// Raised when a path holding key material did not end up owner-only.
///
/// A **typed** failure rather than a `StateError` for a reason that is about
/// custody, not ergonomics: the message of an exception in this directory may
/// reach a session log and a durable column, and this one has to be provably
/// free of anything but a path and a mode. `secretlessDescription` composes from
/// three closed fields and nothing else, so it is auditable by inspection rather
/// than by trusting whoever wrote the `catch` that reports it.
class PosixPermissionException implements Exception, AuditedFailure {
  PosixPermissionException({
    required this.path,
    required this.intendedMode,
    this.actualMode,
    this.detail,
  });

  /// The path whose mode was wrong.
  final String path;

  /// What was asked for, e.g. `600`.
  final String intendedMode;

  /// What the path actually reads as after `chmod`, when it could be read.
  final String? actualMode;

  /// Which step failed: `chmod`, `stat`, or the post-write verification.
  final String? detail;

  @override
  String get secretlessDescription => actualMode == null
      ? 'PosixPermissionException: could not enforce mode $intendedMode on '
            '$path${detail == null ? '' : ' ($detail)'}'
      : 'PosixPermissionException: $path reads $actualMode after chmod '
            '$intendedMode; refusing to leave key material with weaker '
            'permissions than required';

  @override
  String toString() => secretlessDescription;
}

/// Owner-only file modes, applied by shelling out to `chmod`.
///
/// WHY NOT `dart:io`. Dart's `File.writeAsBytes` and `Directory.create` create
/// with `0666`/`0777` masked by the process umask and offer **no** way to set a
/// mode, and expose no `chmod`/`stat`. Under the near-universal umask `022` that
/// is `0644`: readable by every local account. For an ordinary file that is
/// untidy; for the file holding a repository's deploy-key private half it is the
/// failure ADR 0018 §A1 was written to prevent, and it would be invisible —
/// nothing throws, the write "succeeds", and the row records a verified
/// credential.
///
/// So the mode is set explicitly, and then *verified*, rather than trusted. The
/// verification is what turns this from "we asked for 600" into "the file is
/// 600": a `chmod` that a wrapper script intercepted, or that a filesystem
/// mounted `noacl` ignored, leaves a wrong mode and must fail the write instead
/// of returning a credential whose custody nobody checked.
///
/// POSIX-only by design. Both callers — the ADR 0018 §A1 local store
/// (`~/.config/shipit/platform/` chmod 600) and the ADR 0018 §A2 verification
/// identity file — are specified against POSIX permissions. Where they are
/// unavailable this throws rather than degrading to a weaker mode, because
/// silently creating a readable key file is the failure mode this class exists
/// to make impossible.
abstract final class PosixFileModes {
  /// `rwx------` for directories holding key material.
  static const String directory = '700';

  /// `rw-------` for files holding key material.
  static const String file = '600';

  /// Applies [mode] to [path] and then asserts the result.
  ///
  /// Throws [PosixPermissionException] when `chmod` is unavailable, exits
  /// non-zero, or the resulting mode is not exactly [mode]. Set-then-verify, not
  /// set-and-hope.
  static void applyStrict(String path, String mode) {
    final chmod = Process.runSync('chmod', [mode, path]);
    if (chmod.exitCode != 0) {
      throw PosixPermissionException(
        path: path,
        intendedMode: mode,
        detail: 'chmod exited ${chmod.exitCode}',
      );
    }
    final actual = readOctal(path);
    if (actual != mode) {
      throw PosixPermissionException(
        path: path,
        intendedMode: mode,
        actualMode: actual,
      );
    }
  }

  /// Reads a path's permission bits as an octal string such as `600`.
  ///
  /// Tries the BSD (`stat -f %Lp`, macOS) and GNU (`stat -c %a`, Linux) forms.
  /// The development machine is macOS and the CI image is Linux, so anything
  /// asserting on modes has to work on both.
  static String readOctal(String path) {
    final forms = <List<String>>[
      ['-f', '%Lp', path], // BSD / macOS
      ['-c', '%a', path], // GNU / Linux
    ];
    for (final arguments in forms) {
      final result = Process.runSync('stat', arguments);
      if (result.exitCode == 0) {
        final value = (result.stdout as String).trim();
        if (RegExp(r'^[0-7]{3,4}$').hasMatch(value)) return value;
      }
    }
    throw PosixPermissionException(
      path: path,
      intendedMode: '(unreadable)',
      detail:
          'no usable `stat` form; POSIX permission enforcement is mandatory '
          'on paths that hold key material, so this is a refusal rather than a '
          'fallback',
    );
  }

  /// Creates [directoryPath] recursively and asserts the leaf is owner-only.
  ///
  /// Only the leaf is asserted. `createSync(recursive: true)` applies the umask
  /// to intermediate levels too, but those are pre-existing directories such as
  /// `$HOME` or `~/.config` — the operator's own, and not this code's business
  /// to re-chmod. The leaf is the directory that holds key material, and that
  /// one is enforced.
  static void createOwnerOnlyDirectory(String directoryPath) {
    Directory(directoryPath).createSync(recursive: true);
    applyStrict(directoryPath, PosixFileModes.directory);
  }

  /// Writes [bytes] to [path] with owner-only permissions, atomically.
  ///
  /// The content goes to a sibling temp file that is chmod'd *before* any of it
  /// reaches the file, and only then renamed over the destination. Creating the
  /// destination with content and tightening the mode afterwards leaves a window
  /// in which the private half sits on disk at `0644`, and a credential written
  /// over an existing destination is widened by neither the umask nor the
  /// rename. Writing to a 0600 temp file first means the key has never existed
  /// at any other mode.
  static void writeOwnerOnlyFile(String path, List<int> bytes) {
    final temp = '$path.tmp-${pid.toRadixString(16)}';
    try {
      File(temp).writeAsBytesSync(bytes, flush: true);
      applyStrict(temp, PosixFileModes.file);
      File(temp).renameSync(path);
      applyStrict(path, PosixFileModes.file);
    } finally {
      final leftover = File(temp);
      if (leftover.existsSync()) leftover.deleteSync();
    }
  }
}
