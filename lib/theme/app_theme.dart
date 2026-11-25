import 'package:material_ui/material_ui.dart';

class AppColors {
  const AppColors._();

  static const seed = Color(0xFF499AE0);
  static const lightSurface = Color(0xFFF4F8FD);
  static const darkSurface = Color(0xFF0F1419);

  static const coursePaletteLight = [
    Color(0xFFDCEBFA),
    Color(0xFFF9E3EC),
    Color(0xFFE4F3E1),
    Color(0xFFFFF0D2),
    Color(0xFFEAE5FB),
    Color(0xFFDFF3F1),
  ];
  static const coursePaletteDark = [
    Color(0xFF1D3246),
    Color(0xFF3A2531),
    Color(0xFF23382A),
    Color(0xFF3A3221),
    Color(0xFF2D2842),
    Color(0xFF1F3736),
  ];
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.light,
    );
    final scheme = base.copyWith(
      primary: const Color(0xFF2F7FCB),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD8EBFC),
      onPrimaryContainer: const Color(0xFF0B3554),
      secondary: const Color(0xFF6CA6E8),
      secondaryContainer: const Color(0xFFE3F0FC),
      onSecondaryContainer: const Color(0xFF17344D),
      tertiary: const Color(0xFF8E97F0),
      tertiaryContainer: const Color(0xFFE9E9FC),
      surface: AppColors.lightSurface,
      onSurface: const Color(0xFF17222D),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF0F6FD),
      surfaceContainer: const Color(0xFFEAF2FC),
      surfaceContainerHigh: const Color(0xFFE3EEFA),
      surfaceContainerHighest: const Color(0xFFDCE9F8),
      outline: const Color(0xFF7B8FA3),
      outlineVariant: const Color(0xFFDCE7F3),
      error: const Color(0xFFBA4A4A),
      errorContainer: const Color(0xFFFCE8E8),
      onErrorContainer: const Color(0xFF5B1B1B),
    );
    return _build(scheme);
  }

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
    );
    final scheme = base.copyWith(
      primary: const Color(0xFF9BCBF5),
      onPrimary: const Color(0xFF0A2A40),
      primaryContainer: const Color(0xFF1B3B54),
      onPrimaryContainer: const Color(0xFFD6EAFB),
      secondary: const Color(0xFF87B6EA),
      secondaryContainer: const Color(0xFF203548),
      onSecondaryContainer: const Color(0xFFD8E8F8),
      tertiary: const Color(0xFFB9B3F5),
      tertiaryContainer: const Color(0xFF2D2A4A),
      surface: AppColors.darkSurface,
      onSurface: const Color(0xFFE8EEF5),
      surfaceContainerLowest: const Color(0xFF151C23),
      surfaceContainerLow: const Color(0xFF1A232B),
      surfaceContainer: const Color(0xFF1F2933),
      surfaceContainerHigh: const Color(0xFF24303B),
      surfaceContainerHighest: const Color(0xFF2A3744),
      outline: const Color(0xFF8AA0B4),
      outlineVariant: const Color(0xFF31404D),
      error: const Color(0xFFFFB4AB),
      errorContainer: const Color(0xFF54201D),
      onErrorContainer: const Color(0xFFFFDAD6),
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
    );
    final textTheme = base.textTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.94),
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        modalBackgroundColor: scheme.surfaceContainerLowest,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
