/// Single source of truth for theme + component styling. The Material 3
/// ColorScheme is fully spelled out (not derived from a seed), so every
/// component slot uses an intentional brand color instead of the
/// auto-generated values that previously bled orange into FilledButton.tonal,
/// FAB, and selected chips.
///
/// Palette aligns with `dashboard/src/theme/LightTheme.ts` &
/// `DarkTheme.ts` (the original Vuetify "PurpleTheme" -- blue primary +
/// deep-purple secondary). Container shades are explicitly chosen so
/// FilledButton.tonal, primaryContainer, secondaryContainer all stay in
/// the same hue family.
library;

import 'package:flutter/material.dart';

class _Brand {
  // Primary (blue)
  static const primary = Color(0xFF1E88E5);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainerLight = Color(0xFFD9E8FA);
  static const onPrimaryContainerLight = Color(0xFF003966);
  static const primaryContainerDark = Color(0xFF1565C0);
  static const onPrimaryContainerDark = Color(0xFFE2EEFB);

  // Secondary (deep purple)
  static const secondary = Color(0xFF5E35B1);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainerLight = Color(0xFFEDE7F6);
  static const onSecondaryContainerLight = Color(0xFF22095C);
  static const secondaryContainerDark = Color(0xFF4527A0);
  static const onSecondaryContainerDark = Color(0xFFEDE7F6);

  // Tertiary (cyan / info accent)
  static const tertiary = Color(0xFF00ACC1);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainerLight = Color(0xFFCEEAF1);
  static const onTertiaryContainerLight = Color(0xFF00363C);
  static const tertiaryContainerDark = Color(0xFF006978);
  static const onTertiaryContainerDark = Color(0xFFB6EBF5);

  // Error (red)
  static const error = Color(0xFFE53935);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainerLight = Color(0xFFFCE4E4);
  static const onErrorContainerLight = Color(0xFF7F0000);
  static const errorContainerDark = Color(0xFF8C0009);
  static const onErrorContainerDark = Color(0xFFFCE4E4);
}

class AppTheme {
  static ThemeData light() {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary: _Brand.primary,
      onPrimary: _Brand.onPrimary,
      primaryContainer: _Brand.primaryContainerLight,
      onPrimaryContainer: _Brand.onPrimaryContainerLight,
      secondary: _Brand.secondary,
      onSecondary: _Brand.onSecondary,
      secondaryContainer: _Brand.secondaryContainerLight,
      onSecondaryContainer: _Brand.onSecondaryContainerLight,
      tertiary: _Brand.tertiary,
      onTertiary: _Brand.onTertiary,
      tertiaryContainer: _Brand.tertiaryContainerLight,
      onTertiaryContainer: _Brand.onTertiaryContainerLight,
      error: _Brand.error,
      onError: _Brand.onError,
      errorContainer: _Brand.errorContainerLight,
      onErrorContainer: _Brand.onErrorContainerLight,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1B1C1D),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFAFBFD),
      surfaceContainer: Color(0xFFF4F6FA),
      surfaceContainerHigh: Color(0xFFEEF2F6),
      surfaceContainerHighest: Color(0xFFE7EBF4),
      surfaceDim: Color(0xFFE0E4EC),
      surfaceBright: Color(0xFFFFFFFF),
      onSurfaceVariant: Color(0xFF454A52),
      outline: Color(0xFF74787F),
      outlineVariant: Color(0xFFC7CCD4),
      inverseSurface: Color(0xFF2A2C30),
      onInverseSurface: Color(0xFFEEF2F6),
      inversePrimary: Color(0xFF8FBFEE),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      surfaceTint: _Brand.primary,
    );
    return _build(cs);
  }

  static ThemeData dark() {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF6FB1F2),
      onPrimary: Color(0xFF002B53),
      primaryContainer: _Brand.primaryContainerDark,
      onPrimaryContainer: _Brand.onPrimaryContainerDark,
      secondary: Color(0xFF9678D9),
      onSecondary: Color(0xFF1F0455),
      secondaryContainer: _Brand.secondaryContainerDark,
      onSecondaryContainer: _Brand.onSecondaryContainerDark,
      tertiary: Color(0xFF6BD3E2),
      onTertiary: Color(0xFF003640),
      tertiaryContainer: _Brand.tertiaryContainerDark,
      onTertiaryContainer: _Brand.onTertiaryContainerDark,
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690004),
      errorContainer: _Brand.errorContainerDark,
      onErrorContainer: _Brand.onErrorContainerDark,
      surface: Color(0xFF181A1F),
      onSurface: Color(0xFFE5E7EB),
      surfaceContainerLowest: Color(0xFF101115),
      surfaceContainerLow: Color(0xFF1B1D22),
      surfaceContainer: Color(0xFF1F2228),
      surfaceContainerHigh: Color(0xFF272A30),
      surfaceContainerHighest: Color(0xFF31343B),
      surfaceDim: Color(0xFF111317),
      surfaceBright: Color(0xFF383B41),
      onSurfaceVariant: Color(0xFFC4C7CD),
      outline: Color(0xFF8E9197),
      outlineVariant: Color(0xFF44474C),
      inverseSurface: Color(0xFFE5E7EB),
      onInverseSurface: Color(0xFF1B1D22),
      inversePrimary: _Brand.primary,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      surfaceTint: Color(0xFF6FB1F2),
    );
    return _build(cs);
  }

  static ThemeData _build(ColorScheme cs) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      // ----------------------------------------------------------- typography
      textTheme: base.textTheme.apply(
        bodyColor: cs.onSurface,
        displayColor: cs.onSurface,
      ),
      // ----------------------------------------------------------- AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: cs.onSurface,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        iconTheme: IconThemeData(color: cs.onSurfaceVariant),
        actionsIconTheme: IconThemeData(color: cs.onSurfaceVariant),
        shape: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      // ----------------------------------------------------------- Card
      cardTheme: CardThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      // ----------------------------------------------------------- Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          minimumSize: const Size.fromHeight(44),
          side: BorderSide(color: cs.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: cs.onSurfaceVariant,
        ),
      ),
      // ----------------------------------------------------------- FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      // ----------------------------------------------------------- Chip
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        selectedColor: cs.primary.withValues(alpha: 0.18),
        secondarySelectedColor: cs.primary.withValues(alpha: 0.18),
        labelStyle: TextStyle(color: cs.onSurface),
        secondaryLabelStyle: TextStyle(color: cs.primary),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        showCheckmark: false,
      ),
      // ----------------------------------------------------------- Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLow,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
      ),
      // ----------------------------------------------------------- Lists / nav
      listTileTheme: ListTileThemeData(
        iconColor: cs.onSurfaceVariant,
        textColor: cs.onSurface,
        selectedColor: cs.primary,
        selectedTileColor: cs.primary.withValues(alpha: 0.08),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        indicatorColor: cs.primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? cs.primary
                : cs.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            fontSize: 11,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? cs.primary
                : cs.onSurfaceVariant,
          ),
        ),
        height: 64,
      ),
      // ----------------------------------------------------------- Tab bar
      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        dividerColor: cs.outlineVariant,
      ),
      // ----------------------------------------------------------- Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.onPrimary;
          return cs.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.primary;
          return cs.surfaceContainerHigh;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => cs.outlineVariant,
        ),
      ),
      // ----------------------------------------------------------- Dialog / Sheet
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: cs.surface,
        modalBarrierColor: cs.scrim.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
      ),
      // ----------------------------------------------------------- Misc
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.surfaceContainerHigh,
        thumbColor: cs.primary,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: cs.onSurface),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(cs.surface),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
        textStyle: TextStyle(color: cs.onSurface),
      ),
    );
  }
}
