import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pejabat_hr/theme.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  for (final b in Brightness.values) {
    test('text contrast meets WCAG AA in ${b.name} theme', () {
      final s = buildTheme(b).colorScheme;
      final pairs = <String, (Color, Color)>{
        'muted on page': (s.onSurfaceVariant, s.surfaceContainerLowest),
        'muted on card': (s.onSurfaceVariant, s.surface),
        'muted on grey': (s.onSurfaceVariant, s.surfaceContainer),
        'text on page': (s.onSurface, s.surfaceContainerLowest),
        'on primary': (s.onPrimary, s.primary),
        'on primary container': (s.onPrimaryContainer, s.primaryContainer),
        'on secondary container': (s.onSecondaryContainer, s.secondaryContainer),
      };
      for (final e in pairs.entries) {
        expect(contrast(e.value.$1, e.value.$2), greaterThanOrEqualTo(4.5), reason: e.key);
      }
    });
  }

  testWidgets('status tags readable', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(b),
        home: Builder(builder: (context) {
          for (final tone in ['ok', 'warn', 'bad', 'mute']) {
            final c = statusColors(context, tone);
            final bg = tone == 'mute' ? Theme.of(context).colorScheme.surfaceContainerHighest : c.bg;
            expect(contrast(c.fg, bg), greaterThanOrEqualTo(4.5), reason: '$tone ${b.name}');
          }
          return const SizedBox();
        }),
      ));
    }
  });
}
