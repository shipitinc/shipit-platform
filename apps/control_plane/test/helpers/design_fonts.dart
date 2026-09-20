import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers the bundled design typefaces with the test font collection.
///
/// Widget tests otherwise render every glyph in a fallback font whose advance
/// is one em, which makes text ~2x wider than IBM Plex and invalidates any
/// visual comparison against the Penpot boards. Loading the real fonts is what
/// makes a golden meaningful as a fidelity check.
///
/// Call from `setUpAll`.
Future<void> loadDesignFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const families = <String, List<String>>{
    'Orbitron': ['assets/fonts/Orbitron-VariableFont_wght.ttf'],
    'IBM Plex Sans': [
      'assets/fonts/IBMPlexSans-Regular.ttf',
      'assets/fonts/IBMPlexSans-Medium.ttf',
      'assets/fonts/IBMPlexSans-SemiBold.ttf',
    ],
    'IBM Plex Mono': [
      'assets/fonts/IBMPlexMono-Light.ttf',
      'assets/fonts/IBMPlexMono-Regular.ttf',
      'assets/fonts/IBMPlexMono-Medium.ttf',
      'assets/fonts/IBMPlexMono-SemiBold.ttf',
    ],
  };

  for (final family in families.entries) {
    final loader = FontLoader(family.key);
    for (final asset in family.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}
