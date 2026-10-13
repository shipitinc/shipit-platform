import 'dart:io';

import 'package:control_plane_server/server.dart'
    show resolveDurableWorkspaceProvisionInstruction;
import 'package:test/test.dart';

/// The A3 operator surface, as REACHABLE from the QA stack.
///
/// ## THE GAP THIS EXISTS FOR
///
/// A3 shipped an operator-triggered durable-workspace provision instruction,
/// `SHIPIT_PROVISION_DURABLE_WORKSPACE`, read once at boot in
/// `apps/server/lib/server.dart`. It was unreachable: measured in the running
/// container, `docker exec docker-server-1 sh -c 'echo "$<VAR>"'` with
/// `VAR=SHIPIT_PROVISION_DURABLE_WORKSPACE` printed `<unset>`, while
/// `SHIPIT_DURABLE_WORKSPACE_ROOT` — A1's value, a few lines away in the same
/// block — was present.
///
/// The cause is not a bug anywhere. **Compose hands a container only the
/// variables its service DECLARES.** A1 declared its variable; nothing declared
/// A3's. The implementation was correct, the reviewer correctly ruled the
/// trigger safe to execute, and the surface still did not exist — which is why
/// this test reads the compose file rather than the Dart.
///
/// ## WHY THIS IS A TEXT TEST, AND WHY THAT IS NOT A WEAKNESS
///
/// Two alternatives were weighed.
///
/// A real `docker compose -f docker/compose.qa.yaml config` render would be the
/// strongest evidence, and it IS read-only — it never contacts the daemon. But
/// it cannot be the committed gate: `apps/server`'s suite runs wherever
/// `dart test` runs, and making a required unit gate depend on a Docker CLI
/// being installed turns an environment into a pass/fail input. AGENTS.md is
/// blunter still — it withholds `docker compose config` from every lane that
/// holds no infrastructure authority, and calls the compose file "readable as
/// text" precisely because that is the supported way to establish what a stack
/// declares. So the render is not the gate; it is the one-time empirical
/// confirmation the lane ran by hand, and the command to reproduce it is in
/// [reproduction] below.
///
/// A real YAML parse would be the other alternative, and there is no `yaml`
/// package to do it with: adding one means editing `apps/server/pubspec.yaml`,
/// which is not this lane's to edit, and a hand-rolled lexer would be a second
/// Compose parser to be wrong in a new way. So the block is extracted
/// **structurally, by indentation** — not by `contains` — and the assertions are
/// about the extracted key/value pairs. That is strictly more than the
/// repository's existing compose-file test, which greps whole-file text and so
/// cannot tell which SERVICE declares what.
///
/// ## THE INTERPOLATION IS APPLIED, NOT ASSUMED
///
/// The declared scalar is run through the substitution Compose performs, and
/// the RESULT is handed to the production parser. So "the JSON survives
/// interpolation" is not a claim about the shape of the declaration; it is a
/// round-trip: the exact bytes Compose would substitute, parsed by the exact
/// function `server.dart` calls at boot. A declaration that stopped carrying
/// the value, or that carried it through a form that mangled a brace or a
/// quote, fails here.
const String _envName = 'SHIPIT_PROVISION_DURABLE_WORKSPACE';

const String _composeFile = 'docker/compose.qa.yaml';

/// The exact bytes an operator writes into `docker/.env`, taken from the live
/// one: no spaces after the colons, so it is the tightest form the format has to
/// carry — and it exercises the characters the substitution must not touch.
///
/// A prettier fixture (`{"a": 1}`) would survive a substitution that stripped
/// quotes or ate a brace only because the parser is lenient about whitespace.
/// This one is asserted below for exactly the characters it contains, so the
/// fixture cannot quietly become harmless — and, when it does not contain one,
/// so the gap is recorded rather than assumed away.
const String _instructionJson =
    '{"productId":"shipit-platform","repositoryId":"shipit-platform",'
    '"startingRevision":"f58d6fb129c1d4265ada5af9dc359eb5ac27a9a2"}';

void main() {
  group('the server service DECLARES the key', () {
    test('it is on `server`, not merely somewhere in the file', () {
      expect(
        _serverEnvironment()[_envName],
        isNotNull,
        reason:
            '$_composeFile no longer declares $_envName under services.server. '
            'Compose passes a container only the variables its service declares, '
            'so without this line the operator instruction stays in docker/.env '
            'and never reaches the container — the exact state this test was '
            'written for.',
      );
    });

    test('declared exactly once, so no other service acquires it silently', () {
      final occurrences = _composeText()
          .split('\n')
          .where((line) => line.contains(_envName))
          // Comment lines document the key; only a declaration counts.
          .where((line) => !line.trimLeft().startsWith('#'))
          .toList();

      expect(
        occurrences,
        hasLength(1),
        reason:
            '$_envName must be declared on services.server and nowhere else. '
            'Found: $occurrences',
      );
    });

    test('it is the interpolation form, with an EMPTY default', () {
      // Quoting is part of the contract: it keeps Compose treating the value as
      // a string scalar rather than letting the JSON's own punctuation reach
      // YAML. `:-}` is the empty default — see the no-op group for why the
      // default must stay empty and why a required `${VAR:?...}` is forbidden.
      expect(
        _serverEnvironment()[_envName],
        '"\${$_envName:-}"',
        reason:
            '$_composeFile must declare $_envName as "\${$_envName:-}". '
            'A different form does not reach the container, or reaches it '
            'changed. Note the comments above SHIPIT_SECRET_PROVIDER and '
            'SHIPIT_HOST_KEY_FINGERPRINT: Compose interpolates the whole file '
            'before filtering services, so a mandatory \${VAR:?...} would break '
            'every command that reads this file.',
      );
    });

    test('and its documentation is attached to it', () {
      final lines = _composeText().split('\n');
      final index = lines.indexWhere(
        (line) =>
            line.contains('$_envName:') && !line.trimLeft().startsWith('#'),
      );
      expect(index, isNonNegative, reason: '$_composeFile has no declaration');

      final above = lines.sublist(0, index).join('\n');
      expect(
        above,
        contains('OPERATOR SURFACE'),
        reason:
            'the comment above the declaration must say what the variable IS, '
            'so the next editor knows it is A3\'s operator trigger and not a '
            'stray leftover',
      );
      expect(
        above,
        contains('CLEAR IT'),
        reason:
            'the comment must say the variable may be cleared once the clone '
            'exists. A3 made a re-presentation a satisfied outcome rather than a '
            'failure, so leaving it set is safe — but only an operator who was '
            'TOLD can do the housekeeping, and this is the only place they look',
      );
      expect(
        above,
        contains('docker/.env'),
        reason:
            'the comment must record which of the two .env files supplies the '
            'value. Compose interpolation and `env_file:` are different '
            'mechanisms reading different files; that distinction is the reason '
            'this line was ever missing',
      );
    });
  });

  group('UNSET IS A NO-OP — the everyday case stays boring', () {
    test('the declaration renders EMPTY when the host variable is absent', () {
      // What Compose substitutes for an absent variable. Not null, not the
      // literal "${SHIPIT_...}" placeholder — that is the failure mode the
      // client service's SHIPIT_HOST_KEY_FINGERPRINT comment warns about, and
      // it is worth asserting rather than trusting.
      final rendered = _interpolate(_serverEnvironment()[_envName]!);

      expect(rendered, isEmpty);
      expect(
        rendered,
        isNot(contains(r'${')),
        reason:
            'an unset variable must never reach the container as a '
            'placeholder that the server would then try to parse as JSON',
      );
    });

    test('and an empty one is what the server reads as "nobody asked"', () {
      final rendered = _interpolate(_serverEnvironment()[_envName]!);
      final parsed = resolveDurableWorkspaceProvisionInstruction({
        _envName: rendered,
      });

      expect(
        parsed,
        isNull,
        reason:
            'this is the boot a QA stack takes on nearly every start, and it '
            'must be indistinguishable from a stack where this line was never '
            'written: no instruction, no provisioning, no refusal. Absence is a '
            'STATE, not a fault — see durable_workspace_provision_instruction_'
            'test.dart for that contract asserted on its own',
      );
    });

    test('an empty host value is equally a no-op, not a fault', () {
      // The other half of unset: an operator who exported it empty on a later
      // start must not have their platform refuse to boot. `:-` treats empty as
      // unset, so this holds for the same reason.
      final rendered = _interpolate(
        _serverEnvironment()[_envName]!,
        hostValue: '',
      );

      expect(rendered, isEmpty);
      expect(
        resolveDurableWorkspaceProvisionInstruction({_envName: rendered}),
        isNull,
      );
    });
  });

  group('the JSON survives interpolation BYTE-FOR-BYTE', () {
    test('the fixture carries the characters that could break it', () {
      // Guards the fixture, not the declaration. A future edit that "tidied"
      // this JSON into something a lenient parser accepts would quietly delete
      // the reason this test is not redundant.
      //
      // `{`, `}` and `"` only, and that is the TRUTH about the shipped
      // instruction: productId, repositoryId and a SHA carry no `/`. An earlier
      // draft of this file also demanded `/` here and failed, which is the
      // guard doing its job. The slash risk is real but belongs to the
      // declaration's NEIGHBOURS — SHIPIT_HOST_SECRET_DIR and
      // SHIPIT_HOST_WORKSPACE_DIR are host paths through this very
      // substitution — so it is asserted where it is true, below.
      for (final character in ['{', '}', '"']) {
        expect(
          _instructionJson,
          contains(character),
          reason:
              'the fixture no longer contains $character, so it no longer '
              'exercises the substitution risk this test exists to rule out',
        );
      }
      expect(
        _instructionJson,
        isNot(contains('/')),
        reason:
            'the shipped instruction has no slash. If a future one does, this '
            'assertion is what should be updated — not silently relaxed',
      );
    });

    test('the substituted value is the instruction, unchanged', () {
      final rendered = _interpolate(
        _serverEnvironment()[_envName]!,
        hostValue: _instructionJson,
      );

      expect(
        rendered,
        _instructionJson,
        reason:
            'the bytes Compose would substitute are not the bytes in '
            'docker/.env. Anything that escaped, re-quoted or re-ordered the '
            'JSON here would provision the wrong revision — or refuse to boot '
            'with a CONFIG_ERROR an operator has to decode by hand',
      );
    });

    test('and a PATH-bearing value survives the same substitution', () {
      // The `/` half of the risk, asserted where it is true. The same scalar
      // declaration is how SHIPIT_HOST_SECRET_DIR and
      // SHIPIT_HOST_WORKSPACE_DIR carry `/Users/...` host paths into this
      // stack, so a substitution that mishandled a slash would be a bug in
      // custody and workspace mounts too, not only in this operator trigger.
      const pathBearing =
          '{"productId":"org/team","repositoryId":"shipit/shipit-platform",'
          '"startingRevision":"f58d6fb129c1d4265ada5af9dc359eb5ac27a9a2"}';
      expect(pathBearing, contains('/'));

      final rendered = _interpolate(
        _serverEnvironment()[_envName]!,
        hostValue: pathBearing,
      );
      expect(rendered, pathBearing);

      final parsed = resolveDurableWorkspaceProvisionInstruction({
        _envName: rendered,
      });
      expect(parsed, isNotNull);
      expect(parsed!.productId, 'org/team');
      expect(
        parsed.repositoryId,
        'shipit/shipit-platform',
        reason:
            'a slash eaten or doubled here would resolve the wrong repository '
            'and clone the wrong product — silently, because a wrong id is not '
            'a malformed instruction and so is not refused',
      );
    });

    test('the REAL parser reads all three fields out of the substitution', () {
      // The end of the round-trip. Not "the string looks right" but "the exact
      // function `server.dart` calls at boot returns the instruction the
      // operator asked for".
      final rendered = _interpolate(
        _serverEnvironment()[_envName]!,
        hostValue: _instructionJson,
      );
      final parsed = resolveDurableWorkspaceProvisionInstruction({
        _envName: rendered,
      });

      expect(parsed, isNotNull);
      expect(parsed!.productId, 'shipit-platform');
      expect(parsed.repositoryId, 'shipit-platform');
      expect(
        parsed.startingRevision,
        'f58d6fb129c1d4265ada5af9dc359eb5ac27a9a2',
        reason:
            'startingRevision is the PIN. A mangled JSON that still parsed would '
            'not be refused — it would clone the wrong commit and record it in '
            'onboarding.git_revision, which is the one record downstream review '
            'treats as evidence',
      );
    });
  });
}

/// Command a reviewer runs to discharge, by hand, the one claim this file
/// emulates rather than executes: that Compose substitutes the declared scalar
/// verbatim and never re-lexes the result as YAML.
///
///   tmp="$(mktemp -d)"
///   mkdir -p "$tmp/docker"
///   cp docker/compose.qa.yaml "$tmp/docker/"
///   cp docker/.env "$tmp/docker/.env"          # the real one, gitignored
///   : > "$tmp/.env"                            # env_file: ../.env must exist
///   SHIPIT_PROVISION_DURABLE_WORKSPACE='{"productId":"shipit-platform",\
/// "repositoryId":"shipit-platform",\
/// "startingRevision":"f58d6fb129c1d4265ada5af9dc359eb5ac27a9a2"}' \
///     docker compose -f "$tmp/docker/compose.qa.yaml" config \
///       | grep -A1 'SHIPIT_PROVISION_DURABLE_WORKSPACE'
///   rm -rf "$tmp"
///
/// `config` is a render: it reads files and prints. It creates nothing, and it
/// does not reach the daemon.
const reproduction =
    'docker compose -f <scratch>/docker/compose.qa.yaml config';

/// The substitution Compose performs on `${VAR:-default}` after the YAML scalar
/// has been parsed.
///
/// Compose's rule is that an operator using `:-` substitutes the value when the
/// variable is set AND non-empty, and the (here empty) default otherwise, and
/// that the substituted text is not re-parsed. Only that one form is modelled,
/// because only that one form is declared — asserted above — so this cannot
/// drift into a general-purpose interpolation engine that would need its own
/// tests for behaviour Compose never promised.
String _interpolate(String declared, {String? hostValue}) {
  final open = declared.indexOf(r'${');
  expect(
    open,
    isNonNegative,
    reason:
        '$_composeFile no longer declares an interpolation for $_envName: '
        '$declared',
  );
  final close = declared.indexOf('}', open);
  expect(
    close,
    greaterThan(open),
    reason: 'unterminated interpolation in: $declared',
  );

  // Between `${` and the closing `}` sits `VAR:-default`; `:-` means "default
  // when unset OR empty", and the default here is the empty string.
  final body = declared.substring(open + 2, close);
  expect(
    body.endsWith(':-'),
    isTrue,
    reason:
        'only the \${VAR:-} form is modelled by this helper. The declaration '
        'says: $declared',
  );
  final fallback = body.substring(0, body.length - 2);
  expect(
    fallback,
    _envName,
    reason: 'the declaration interpolates a variable other than $_envName',
  );

  if (hostValue == null || hostValue.isEmpty) return '';
  return hostValue;
}

/// The `environment:` block of the `server` service, as declared in the compose
/// file — keys to the RAW scalar text, quotes included.
///
/// Structural on purpose. A whole-file `contains` cannot distinguish a key
/// declared on `server` from the same key declared on `worker-linux`, which is
/// precisely the class of mistake this file is guarding against: a value that
/// exists and reaches the wrong container is a quieter failure than one that
/// does not exist at all.
///
/// Not a YAML parse, because no `yaml` dependency is available to this package
/// and a second parser would be a second thing to be wrong. Indentation is
/// enough: Compose's own files use a fixed two-space step per level, and the
/// block boundaries below are the only ones that matter here.
Map<String, String> _serverEnvironment() {
  final lines = _composeText().split('\n');

  final service = _indexOfLine(lines, 'server:', indent: 2);
  expect(
    service,
    isNonNegative,
    reason: '$_composeFile declares no `server:` service under `services:`',
  );

  final environment = _indexOfLine(
    lines,
    'environment:',
    indent: 4,
    after: service,
  );
  expect(
    environment,
    isNonNegative,
    reason:
        'the server service of $_composeFile declares no `environment:` '
        'block — and an absent block is how this variable went missing once',
  );

  final declared = <String, String>{};
  for (var i = environment + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;

    final indent = _indentOf(line);
    if (indent <= 4) break; // Next key of the service, or the next service.
    if (indent > 6) continue; // Nested value belonging to the key above.

    final match = RegExp(
      r'^ {6}([A-Za-z_][A-Za-z0-9_]*):[ ]?(.*)$',
    ).firstMatch(line.trimRight());
    if (match != null) declared[match.group(1)!] = match.group(2)!.trim();
  }
  return declared;
}

/// Index of the first line whose trimmed content is [text] at exactly [indent]
/// spaces, searching from [after]. Returns -1 when there is none.
int _indexOfLine(
  List<String> lines,
  String text, {
  required int indent,
  int after = -1,
}) {
  for (var i = after + 1; i < lines.length; i++) {
    if (_indentOf(lines[i]) == indent && lines[i].trim() == text) return i;
  }
  return -1;
}

int _indentOf(String line) => line.length - line.trimLeft().length;

String _composeText() => File(_resolve(_composeFile)).readAsStringSync();

/// Walks up from the package directory so the path does not depend on the
/// working directory the runner happens to use. `Directory.current` is the
/// package root under `dart test`, and `docker/` lives at the repository root
/// above it.
String _resolve(String relative) {
  var dir = Directory.current.absolute;
  while (true) {
    final candidate = File('${dir.path}/$relative');
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'could not locate $relative above ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}
