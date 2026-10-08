/// A git remote resolved into the parts an SSH clone needs.
///
/// Split out from the verifier so the URI grammar is testable without touching
/// a filesystem, and so a malformed remote is a typed refusal at the edge
/// rather than a confusing `git` exit code five layers down.
class SshRemote {
  SshRemote({
    required this.user,
    required this.host,
    required this.port,
    required this.repositoryPath,
  });

  /// SSH user, e.g. `git`.
  final String user;

  /// Hostname or address.
  final String host;

  /// TCP port. 22 unless the URI said otherwise.
  final int port;

  /// Repository path as the host knows it, e.g. `acme/shipit-platform.git`.
  final String repositoryPath;

  /// The `ssh://` form handed to `git clone`.
  ///
  /// The scp-like `git@host:path` syntax git also accepts cannot carry a
  /// non-default port, and this verifier must be able to target a host on a
  /// non-22 port at all — a self-hosted git server is explicitly in scope for
  /// ADR 0018 §Context ("any git host reachable over SSH"). So the remote is
  /// normalised to the URL form, where the port is explicit.
  String toSshUrl() => 'ssh://$user@$host:$port/$repositoryPath';

  @override
  String toString() => 'SshRemote($user@$host:$port/$repositoryPath)';
}

/// Raised when a repository URI cannot be reached with an SSH credential.
///
/// The message names the URI's *scheme* and shape, never key material, and is
/// safe to log.
class UnsupportedRepositoryUriException implements Exception {
  UnsupportedRepositoryUriException(this.message);

  final String message;

  @override
  String toString() => 'UnsupportedRepositoryUriException: $message';
}

/// Default SSH port.
const int kDefaultSshPort = 22;

/// Parses [uri] into an [SshRemote], or refuses it.
///
/// Accepts the two forms a `RepositoryReference.uri` actually takes:
///
///   * scp-like: `git@github.com:acme/shipit-platform.git`
///   * URL:     `ssh://git@github.com:22/acme/shipit-platform.git`
///     (also `ssh://github.com/acme/repo.git`, user defaults to `git`)
///
/// REFUSES anything else, including `https://`. That refusal is the point of
/// the method and not a limitation: ADR 0018 chose SSH because it is the only
/// credential mechanism portable across providers that have no notion of
/// fine-grained tokens, and a repository carrying an `https://` URI has no
/// deploy key to install. Minting a credential for one would create a row that
/// can never reach `verified` and would quietly satisfy the client's
/// `accessStatus == verified` precondition on a repository that was never
/// actually proved reachable.
SshRemote parseSshRemote(String uri) {
  final trimmed = uri.trim();
  if (trimmed.isEmpty) {
    throw UnsupportedRepositoryUriException('the repository URI is empty');
  }

  if (trimmed.startsWith('ssh://')) {
    final parsed = Uri.parse(trimmed);
    final host = parsed.host;
    if (host.isEmpty) {
      throw UnsupportedRepositoryUriException(
        'the ssh:// repository URI names no host',
      );
    }
    final path = parsed.path.startsWith('/')
        ? parsed.path.substring(1)
        : parsed.path;
    if (path.isEmpty) {
      throw UnsupportedRepositoryUriException(
        'the ssh:// repository URI names no repository path',
      );
    }
    // `Uri` exposes the authority's userinfo as one string ("user" or
    // "user:password"), never as a `.user`. A URL carrying a password is refused
    // rather than silently accepted, because a password in a repository URI is
    // exactly the "secret typed into ShipIt" that ADR 0018 §Decision rules out.
    final userInfo = parsed.userInfo;
    if (userInfo.contains(':')) {
      throw UnsupportedRepositoryUriException(
        'the ssh:// repository URI carries a password. ADR 0018 credentials are '
        'SSH deploy keys; no secret value may appear in a repository URI.',
      );
    }
    return SshRemote(
      user: userInfo.isEmpty ? 'git' : userInfo,
      host: host,
      port: parsed.hasPort ? parsed.port : kDefaultSshPort,
      repositoryPath: path,
    );
  }

  // scp-like `user@host:path`. Anchored so a `https://` URI cannot fall through
  // and be misread as user `https`, host `//`, path `github.com/...`.
  final scpLike = RegExp(
    r'^([A-Za-z0-9._-]+)@([A-Za-z0-9._-]+):(.+)$',
  ).firstMatch(trimmed);
  if (scpLike != null) {
    return SshRemote(
      user: scpLike.group(1)!,
      host: scpLike.group(2)!,
      port: kDefaultSshPort,
      repositoryPath: scpLike.group(3)!.replaceFirst(RegExp(r'^/+'), ''),
    );
  }

  final scheme = trimmed.contains('://')
      ? trimmed.substring(0, trimmed.indexOf('://'))
      : 'none';
  throw UnsupportedRepositoryUriException(
    'the repository URI uses the "$scheme" scheme, but ADR 0018 credentials are '
    'SSH deploy keys and are only usable over ssh:// or scp-like '
    'user@host:path. Minting a credential for this remote would produce a row '
    'that can never reach a verified status.',
  );
}
