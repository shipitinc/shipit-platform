import 'package:agent_runtime/agent_runtime.dart';
import 'package:test/test.dart';

/// `session/set_config_option` with `configId: 'model'` is answered
/// `-32602 "model not found"` for a value the runtime cannot resolve, and the
/// value is sent VERBATIM. A caller that configures a bare `space-bunny-free`
/// or `mimo-v2.6-flash-free` therefore gets a wire-level rejection for what is
/// really a caller-side mistake — and it looks like a well-formed request.
///
/// The rule is therefore enforced at the boundary that sends the value, so it
/// holds for every caller rather than only the ones that remember.
void main() {
  group('qualifyModelId', () {
    test('an unqualified id is given the default provider', () {
      expect(qualifyModelId('space-bunny-free'), 'opencode/space-bunny-free');
      expect(qualifyModelId('big-pickle'), 'opencode/big-pickle');
    });

    test(
      'the design-role id that was previously unqualified qualifies too',
      () {
        // This exact string shipped as the design-role fallback and could never
        // have been applied by the runtime.
        expect(
          qualifyModelId('mimo-v2.6-flash-free'),
          'opencode/mimo-v2.6-flash-free',
        );
      },
    );

    test('an already-qualified id is passed through unchanged', () {
      expect(qualifyModelId('opencode/big-pickle'), 'opencode/big-pickle');
      expect(
        qualifyModelId('anthropic/claude-sonnet-5'),
        'anthropic/claude-sonnet-5',
      );
    });

    test('a provider-namespaced id is NOT split or rewritten, because ids with '
        'more than one slash are real', () {
      // `openrouter/xiaomi/mimo-v2.5` is in the runtime's own registry. Splitting
      // on the first slash and re-joining would corrupt a valid id.
      expect(
        qualifyModelId('openrouter/xiaomi/mimo-v2.5'),
        'openrouter/xiaomi/mimo-v2.5',
      );
      expect(
        qualifyModelId('openrouter/xiaomi/mimo-v2.6-pro-ultraspeed'),
        'openrouter/xiaomi/mimo-v2.6-pro-ultraspeed',
      );
    });

    test('surrounding whitespace is trimmed, not sent on the wire', () {
      expect(qualifyModelId('  big-pickle  '), 'opencode/big-pickle');
      expect(qualifyModelId(' opencode/big-pickle '), 'opencode/big-pickle');
    });

    test('a non-default provider can be assumed', () {
      expect(qualifyModelId('gpt-5', provider: 'openai'), 'openai/gpt-5');
      // An id that already names its provider is never re-pointed at another.
      expect(
        qualifyModelId('anthropic/claude-sonnet-5', provider: 'openai'),
        'anthropic/claude-sonnet-5',
      );
    });

    test(
      'a malformed but slash-bearing id is passed through rather than guessed '
      'at, because the runtime is the authority on what it can resolve',
      () {
        // Manufacturing a corrected id here would turn a precise wire rejection
        // into a silent substitution of a DIFFERENT model.
        expect(qualifyModelId('/foo'), '/foo');
        expect(qualifyModelId('foo/'), 'foo/');
      },
    );

    test('the rule always yields at least one slash', () {
      for (final id in [
        'space-bunny-free',
        'big-pickle',
        'opencode/big-pickle',
        'openrouter/xiaomi/mimo-v2.5',
      ]) {
        expect(qualifyModelId(id), contains('/'), reason: 'for "$id"');
      }
    });
  });
}
