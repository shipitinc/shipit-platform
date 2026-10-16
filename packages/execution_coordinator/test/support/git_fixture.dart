import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';

/// A real git repository in a temp directory, standing in for the detached
/// worktree `GitWorktreeWorkspaceManager` prepares for an execution.
///
/// ## WHY A REAL REPOSITORY AND NOT A MOCK
///
/// The defect this rule closes was measured, not theorised: seven real
/// IMPLEMENTER runs produced nothing. A test that stubs the workspace probe
/// would prove the wiring and nothing about the git command, so the command
/// could be wrong — reading the wrong baseline, missing untracked files, asking
/// git a question it answers with exit 0 and empty output on a clean tree —
/// and every test would still be green.
///
/// The fixture pins exactly the three states that decide an implementation's
/// artifact, including the one that is easy to get wrong: a brand-new file left
/// **untracked and unstaged**, which `git diff --name-status` does not report
/// but `git status --porcelain` does — and which `ArtifactCommitter` commits.
class GitWorkspaceFixture {
  GitWorkspaceFixture._(this.root, this.startingRevision);

  final Directory root;

  /// The commit the "execution" starts from — the baseline every probe compares
  /// against.
  final String startingRevision;

  static final List<String> _identity = [
    '-c',
    'user.name=shipit-fixture',
    '-c',
    'user.email=shipit-fixture@localhost',
    '-c',
    'commit.gpgsign=false',
    // Keeps `git init` from printing a hint and from depending on the ambient
    // default-branch configuration.
    '-c',
    'init.defaultBranch=main',
  ];

  /// Creates a repository with one committed file.
  ///
  /// Throws if git cannot produce one: a fixture that silently falls back to a
  /// plain directory would make every test below it vacuous.
  static GitWorkspaceFixture create(String parent, {String tag = 'git_ws'}) {
    final root = Directory('$parent/$tag')..createSync(recursive: true);
    final fixture = GitWorkspaceFixture._(root, '');
    fixture._git(['init', '--quiet']);
    fixture.writeFile(
      'lib/calculator.dart',
      'int add(int a, int b) => a + b;\n',
    );
    fixture._git(['add', '-A']);
    fixture._git(['commit', '--quiet', '-m', 'baseline']);
    return GitWorkspaceFixture._(root, fixture._git(['rev-parse', 'HEAD']));
  }

  /// The `AgentWorkspace` an execution request for this repository carries.
  AgentWorkspace toWorkspace({String workspaceId = 'ws-git'}) => AgentWorkspace(
    workspaceId: workspaceId,
    path: root.path,
    startingRevision: startingRevision,
  );

  /// Writes (or overwrites) a file WITHOUT staging it — the shape of an agent
  /// that edited and left the worktree dirty.
  void writeFile(String path, String content) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  /// Creates a file git has never heard of: untracked and unstaged.
  ///
  /// This is the case `git diff --name-status <rev>` misses and
  /// `git status --porcelain` reports, and therefore the case a naive probe
  /// would permanently fail.
  void createUntrackedFile(String path, String content) =>
      writeFile(path, content);

  /// Commits the current worktree, moving `HEAD` past [startingRevision].
  String commitAll(String message) {
    _git(['add', '-A']);
    _git(['commit', '--quiet', '-m', message]);
    return _git(['rev-parse', 'HEAD']);
  }

  /// Stages everything without committing — `HEAD` is unmoved but the tree is
  /// dirty.
  void stageAll() => _git(['add', '-A']);

  /// `HEAD` right now, so a test can PROVE the state it set up rather than
  /// assume it.
  ///
  /// Added with the committed-case coverage: a test asserting that a CLEAN tree
  /// with a MOVED `HEAD` counts as produced is vacuous if it never checks that
  /// the tree is clean and `HEAD` moved — it would pass identically through the
  /// dirty branch, having proven nothing about the case it names.
  String get head => _git(['rev-parse', 'HEAD']);

  /// Whether `git status --porcelain` is empty — the same emptiness the probe
  /// reads, read here so a test can assert its own premise.
  bool get isCleanTree => _git(['status', '--porcelain']).isEmpty;

  /// The `git status --porcelain` lines, for a test that needs to see WHICH
  /// shape of dirt it produced.
  List<String> get porcelainLines {
    final out = _git(['status', '--porcelain']);
    if (out.isEmpty) return const [];
    return out.split('\n').where((l) => l.trim().isNotEmpty).toList();
  }

  String _git(List<String> args) {
    final result = Process.runSync('git', [
      ..._identity,
      '-C',
      root.path,
      ...args,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'git ${args.join(' ')} failed in ${root.path}: '
        '${result.stderr}',
      );
    }
    return (result.stdout as String).trim();
  }

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
