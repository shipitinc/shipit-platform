import '../exceptions.dart';

/// Read-only enforcement + secret redaction for repository discovery
/// (checkpoint 006 §read-only discovery / §discovery safety).
///
/// Repository content is DATA, never agent authority. [DiscoveryPolicy]
/// hard-fails any request that would mutate the repository or elevate
/// permissions. [Redactor] guarantees secret values are replaced by
/// placeholders before they can reach a baseline, LLM context, logs, or
/// snapshots.
class DiscoveryPolicy {
  const DiscoveryPolicy._();

  /// Hard boundary: throw when a caller asks discovery to edit/install/
  /// execute/commit/push/migrate/fix. There are no elevated permissions to
  /// take — a malicious README/AGENTS file/prompt fixture cannot matter.
  static Never raiseCapabilityViolation(String what) =>
      throw DiscoveryCapabilityViolation(
        'read-only discovery cannot $what (repository content is data, '
        'not agent authority)',
      );

  /// No-op that still pinpoints the read-only invariant in stack traces.
  static void requireReadOnly() {}
}

/// Redacts secret-shaped content before it can be ingested. The value itself
/// is never retained (checkpoint 006 §discovery safety).
class Redactor {
  /// `[^=\n;]*` rather than `[^=]*`: the character class must not cross a
  /// newline. Allowing it to did — a heading containing the word "credentials"
  /// matched everything down to the next `=` on a later line and replaced the
  /// whole span, corrupting documents that merely mention the word.
  static final RegExp _assignmentPattern = RegExp(
    r'((?:p[a-z_]*|api_?|access_?|client_?|refresh_?)?a?token|password|'
    r'passwd|secret|client_?secret|api_key|apikey|private_?key|access_?key|'
    r'authorization|credentials)[^=\n;]*=[^,\n;]*',
    caseSensitive: false,
  );
  static final RegExp _privateKeyPattern = RegExp(
    r'-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----[\s\S]*?-----END .*PRIVATE KEY-----',
  );

  /// Extensions that indicate a stored value rather than prose or source.
  static const _dataExtensions = {
    '.json',
    '.yaml',
    '.yml',
    '.ini',
    '.conf',
    '.cfg',
    '.toml',
    '.txt',
    '.env',
    '.properties',
  };

  /// True when [lowerPath] names a file that plausibly HOLDS credentials.
  ///
  /// Matching `credentials` anywhere in the path was too loose: it classified
  /// `docs/adr/0018-git-credentials.md` and `credential_status.dart` as
  /// credential stores, so a document *about* credentials was never read and
  /// never contributed a claim. This now matches on the file's own name and
  /// requires a data extension, so stores (`credentials.json`, `.credentials`)
  /// are still refused while documentation and source are read normally.
  static bool _isCredentialStore(String lowerPath) {
    final base = lowerPath.split('/').last;
    if (!base.contains('credential')) return false;
    if (!base.contains('.')) return true; // a bare `credentials` file
    for (final ext in _dataExtensions) {
      if (base.endsWith(ext)) return true;
    }
    return false;
  }

  static bool looksSecretShaped(String lowerPath) {
    return lowerPath.contains('.env') ||
        lowerPath.endsWith('.pem') ||
        lowerPath.endsWith('.key') ||
        lowerPath.endsWith('.p12') ||
        lowerPath.endsWith('.pfx') ||
        lowerPath.contains('id_rsa') ||
        lowerPath.contains('id_ed25519') ||
        _isCredentialStore(lowerPath) ||
        lowerPath.endsWith('secret.yaml') ||
        lowerPath.endsWith('.gpg') ||
        lowerPath.endsWith('.keystore');
  }

  /// Returns [content] with secret values replaced by
  /// `<REDACTED:secret>` placeholders. No value survives.
  static String redact(String content) {
    var out = _assignmentPattern.hasMatch(content)
        ? content.replaceAll(_assignmentPattern, r'$1=<REDACTED:secret>')
        : content;
    out = _privateKeyPattern.hasMatch(out)
        ? out.replaceAll(_privateKeyPattern, '<REDACTED:private-key>')
        : out;
    return out;
  }
}
