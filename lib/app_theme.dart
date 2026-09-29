import 'package:flutter/material.dart';

// ---- 语义色：浅色/深色共用，高饱和色在深底上同样跳 ----
/// 支出 / 收入 / 结余
const Color kExpense = Color(0xFFF43F5E);
const Color kIncome = Color(0xFF10B981);
const Color kBalancePositive = Color(0xFF0EA5E9);
const Color kBalanceNegative = Color(0xFFF59E0B);

// ---- 浅色主题（当前默认）的框架色 ----
const Color kCanvas = Color(0xFFF5F7FF);
const Color kInk = Color(0xFF1B2340);
const Color kInkSoft = Color(0xFF5B6478);
const Color kCard = Colors.white;
const Color kCardBorder = Color(0xFFE1E7F5);
const Color kPrimary = Color(0xFF4C6EF5);
const Color kPrimaryDeep = Color(0xFF3B5BDB);
const Color kPrimarySoft = Color(0xFFE4E9FB);

/// 一套主题的框架色。深色只做「浅黑」处理，不用纯黑，避免生硬。
class _Frame {
  const _Frame({
    required this.brightness,
    required this.canvas,
    required this.ink,
    required this.inkSoft,
    required this.card,
    required this.cardBorder,
    required this.primary,
    required this.onPrimary,
    required this.primaryDeep,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.well,
    required this.outline,
  });

  final Brightness brightness;
  final Color canvas;
  final Color ink;
  final Color inkSoft;
  final Color card;
  final Color cardBorder;
  final Color primary;

  /// 主色底上的文字/图标：浅底配深字，深底配白字
  final Color onPrimary;
  final Color primaryDeep;
  final Color primarySoft;
  final Color onPrimarySoft;
  final Color well;
  final Color outline;
}

const _Frame _light = _Frame(
  brightness: Brightness.light,
  canvas: kCanvas,
  ink: kInk,
  inkSoft: kInkSoft,
  card: kCard,
  cardBorder: kCardBorder,
  primary: kPrimary,
  onPrimary: Colors.white,
  primaryDeep: kPrimaryDeep,
  primarySoft: kPrimarySoft,
  onPrimarySoft: kPrimaryDeep,
  well: Color(0xFFEAEFFB),
  outline: Color(0xFF9AA6C4),
);

const _Frame _dark = _Frame(
  brightness: Brightness.dark,
  canvas: Color(0xFF15171D),
  ink: Color(0xFFE9EDF5),
  inkSoft: Color(0xFF9AA4B8),
  card: Color(0xFF1E222A),
  cardBorder: Color(0xFF2E3441),
  primary: Color(0xFF7C93FF),
  onPrimary: Color(0xFF14161C),
  primaryDeep: Color(0xFF4C6EF5),
  primarySoft: Color(0xFF2A3350),
  onPrimarySoft: Color(0xFFBCCAFF),
  well: Color(0xFF242938),
  outline: Color(0xFF6B7691),
);

ThemeData buildAppTheme() => _buildTheme(_light);

/// 浅黑色深色主题
ThemeData buildDarkAppTheme() => _buildTheme(_dark);

ThemeData _buildTheme(_Frame f) {
  final scheme = ColorScheme(
    brightness: f.brightness,
    primary: f.primary,
    onPrimary: f.onPrimary,
    primaryContainer: f.primarySoft,
    onPrimaryContainer: f.primaryDeep,
    secondary: f.primaryDeep,
    onSecondary: Colors.white,
    secondaryContainer: f.primarySoft,
    onSecondaryContainer: f.primaryDeep,
    surface: f.card,
    onSurface: f.ink,
    surfaceContainerLowest: f.card,
    surfaceContainerLow: f.card,
    surfaceContainer: f.card,
    surfaceContainerHigh: f.canvas,
    surfaceContainerHighest: f.well,
    onSurfaceVariant: f.inkSoft,
    outline: f.outline,
    outlineVariant: f.cardBorder,
    error: kExpense,
    onError: Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: f.canvas,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    cardTheme: CardThemeData(
      elevation: 0,
      color: f.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: f.cardBorder),
      ),
    ),
    dividerTheme: DividerThemeData(color: f.cardBorder, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: f.primary,
      surfaceTintColor: Colors.transparent,
      foregroundColor: f.onPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: f.onPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    textTheme: base.textTheme.apply(bodyColor: f.ink, displayColor: f.ink),
    dialogTheme: DialogThemeData(backgroundColor: f.card),
    listTileTheme: ListTileThemeData(iconColor: f.inkSoft, textColor: f.ink),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: f.card,
      indicatorColor: f.primarySoft,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, color: f.inkSoft)),
      iconTheme: const WidgetStatePropertyAll(IconThemeData(size: 22)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: f.primary,
      foregroundColor: f.onPrimary,
      elevation: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: f.primary,
        foregroundColor: f.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: f.cardBorder)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? f.primarySoft : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? f.onPrimarySoft : f.inkSoft,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: f.primaryDeep,
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor: Colors.white,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
