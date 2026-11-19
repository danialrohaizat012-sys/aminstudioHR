import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The Amin Studio camera mark (assets/brand/logo_mark.png).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/brand/logo_mark.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Logo Amin Studio',
      );
}

/// Mark plus "AMIN STUDIO" wordmark, echoing the shop signboard:
/// black AMIN, red STUDIO.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 44, this.caption = 'Sistem HR'});
  final double markSize;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = TextStyle(
      fontSize: markSize * .42,
      fontWeight: FontWeight.w900,
      letterSpacing: .4,
      height: 1.05,
    );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BrandMark(size: markSize),
      SizedBox(width: markSize * .28),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: 'AMIN ', style: base.copyWith(color: cs.onSurface)),
          TextSpan(text: 'STUDIO', style: base.copyWith(color: brandRed)),
        ])),
        if (caption != null)
          Text(caption!,
              style: TextStyle(
                  fontSize: markSize * .27, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: .3)),
      ]),
    ]);
  }
}
