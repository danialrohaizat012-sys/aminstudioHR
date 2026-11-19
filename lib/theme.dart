import 'package:material_ui/material_ui.dart';

/// Pejabat HR uses one blue for action and selection. Orange, green and red
/// appear only for status (pending, approved, rejected, late).
const brandBlue = Color(0xFF1F5BD8);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: brandBlue,
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xFF8DB0FF) : brandBlue,
    surface: dark ? const Color(0xFF141A26) : Colors.white,
    surfaceContainerLowest: dark ? const Color(0xFF0C111D) : const Color(0xFFF5F6F8),
    surfaceContainerLow: dark ? const Color(0xFF161D2A) : const Color(0xFFF5F6F8),
    surfaceContainer: dark ? const Color(0xFF1A2130) : const Color(0xFFF2F4F7),
    surfaceContainerHighest: dark ? const Color(0xFF242D3D) : const Color(0xFFEAECF0),
    outlineVariant: dark ? const Color(0xFF283142) : const Color(0xFFE4E7EC),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => base.textTheme.labelMedium?.copyWith(
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: .5)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Status colours kept outside the seed scheme so they stay recognisable.
({Color bg, Color fg}) statusColors(BuildContext context, String tone) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (tone) {
    'ok' => dark
        ? (bg: const Color(0xFF0B2B1D), fg: const Color(0xFF47CD89))
        : (bg: const Color(0xFFECFDF3), fg: const Color(0xFF067647)),
    'warn' => dark
        ? (bg: const Color(0xFF33240A), fg: const Color(0xFFFDB022))
        : (bg: const Color(0xFFFFFAEB), fg: const Color(0xFFB54708)),
    'bad' => dark
        ? (bg: const Color(0xFF3A1512), fg: const Color(0xFFF97066))
        : (bg: const Color(0xFFFEF3F2), fg: const Color(0xFFB42318)),
    _ => (
        bg: Theme.of(context).colorScheme.surfaceContainer,
        fg: Theme.of(context).colorScheme.onSurfaceVariant
      ),
  };
}
