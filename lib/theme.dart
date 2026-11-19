import 'package:material_ui/material_ui.dart';

/// Amin Studio palette, taken from the shop signboard: signboard yellow,
/// ink black for actions, signage red for the wordmark. Green, amber and
/// red tags still carry request status.
const brandYellow = Color(0xFFFFCE00);
const brandInk = Color(0xFF141414);
const brandRed = Color(0xFFE0241B);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: brandYellow,
    brightness: brightness,
  ).copyWith(
    primary: dark ? brandYellow : brandInk,
    onPrimary: dark ? brandInk : Colors.white,
    primaryContainer: dark ? const Color(0xFF4D3E00) : const Color(0xFFFFE680),
    onPrimaryContainer: dark ? const Color(0xFFFFE680) : const Color(0xFF241C00),
    surface: dark ? const Color(0xFF1B1A17) : Colors.white,
    onSurface: dark ? const Color(0xFFF2EFE6) : brandInk,
    surfaceContainerLowest: dark ? const Color(0xFF121210) : const Color(0xFFF7F6F1),
    surfaceContainerLow: dark ? const Color(0xFF181715) : const Color(0xFFF7F6F1),
    surfaceContainer: dark ? const Color(0xFF24231F) : const Color(0xFFF1EFE8),
    surfaceContainerHighest: dark ? const Color(0xFF2E2C27) : const Color(0xFFE8E5DC),
    outlineVariant: dark ? const Color(0xFF36342E) : const Color(0xFFE6E2D8),
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
