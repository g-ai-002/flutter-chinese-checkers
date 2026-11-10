import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/system_ui.dart';

/// 棋盘配色方案：底板、孔位与高光的颜色全部集中在这里，切换主题无需改绘制代码。
class BoardTheme {
  const BoardTheme({
    required this.id,
    required this.name,
    required this.plateTop,
    required this.plateBottom,
    required this.plateEdge,
    required this.holeFill,
    required this.holeEdge,
    required this.holeInner,
    required this.tip,
    required this.label,
  });

  final String id;
  final String name;
  final Color plateTop;
  final Color plateBottom;
  final Color plateEdge;
  final Color holeFill;
  final Color holeEdge;
  final Color holeInner;

  /// 棋子落点的浅色高光，用于空位提示。
  final Color tip;
  final Color label;
}

const BoardTheme _jade = BoardTheme(
  id: 'jade',
  name: '竹影',
  plateTop: Color(0xFF2F6B5F),
  plateBottom: Color(0xFF1B4038),
  plateEdge: Color(0xFF123029),
  holeFill: Color(0xFFF3EAD7),
  holeEdge: Color(0xFFCBB896),
  holeInner: Color(0xFFE4D6BC),
  tip: Color(0xFF9BC2B6),
  label: Color(0xFFDCEAE4),
);

const BoardTheme _wood = BoardTheme(
  id: 'wood',
  name: '暖木',
  plateTop: Color(0xFF9C6F43),
  plateBottom: Color(0xFF6B4626),
  plateEdge: Color(0xFF4A2E17),
  holeFill: Color(0xFFF7EDDA),
  holeEdge: Color(0xFFD8BE97),
  holeInner: Color(0xFFE9D8B8),
  tip: Color(0xFFD8B98C),
  label: Color(0xFFF5E6CD),
);

const BoardTheme _ink = BoardTheme(
  id: 'ink',
  name: '夜墨',
  plateTop: Color(0xFF3B4348),
  plateBottom: Color(0xFF20262A),
  plateEdge: Color(0xFF14181B),
  holeFill: Color(0xFFBFC6C4),
  holeEdge: Color(0xFF7E8886),
  holeInner: Color(0xFFAEB6B4),
  tip: Color(0xFF7FA6A0),
  label: Color(0xFFD6DEDB),
);

const List<BoardTheme> kBoardThemes = [_jade, _wood, _ink];

BoardTheme boardThemeOf(String? id) {
  for (final theme in kBoardThemes) {
    if (theme.id == id) return theme;
  }
  return kBoardThemes.first;
}

/// 界面主色：墨绿配朱砂，宣纸底。
const Color appJade = Color(0xFF2F6B5F);
const Color appCinnabar = Color(0xFFB4553F);

ThemeData buildLightTheme({String? fontFamily}) {
  const scheme = ColorScheme.light(
    primary: Color(0xFF2F6B5F),
    onPrimary: Color(0xFFF7FBF8),
    primaryContainer: Color(0xFFD8E7DF),
    onPrimaryContainer: Color(0xFF10322A),
    secondary: Color(0xFF8A6F4E),
    onSecondary: Color(0xFFFFF8F0),
    secondaryContainer: Color(0xFFEADCC8),
    onSecondaryContainer: Color(0xFF33261A),
    tertiary: Color(0xFFB4553F),
    onTertiary: Color(0xFFFFF6F2),
    surface: Color(0xFFFFFDF7),
    onSurface: Color(0xFF26241F),
    surfaceContainerHighest: Color(0xFFF0E9DA),
    onSurfaceVariant: Color(0xFF736C5E),
    outline: Color(0xFFE0D6C3),
    outlineVariant: Color(0xFFEDE4D3),
    error: Color(0xFFB3261E),
    surfaceTint: Colors.transparent,
  );

  return _buildBase(
    colorScheme: scheme,
    scaffoldColor: const Color(0xFFF6F2E8),
    fontFamily: fontFamily,
  );
}

ThemeData buildDarkTheme({String? fontFamily}) {
  const scheme = ColorScheme.dark(
    primary: Color(0xFF8FC9B8),
    onPrimary: Color(0xFF07241D),
    primaryContainer: Color(0xFF1D463C),
    onPrimaryContainer: Color(0xFFD3EDE3),
    secondary: Color(0xFFD3B892),
    onSecondary: Color(0xFF382912),
    secondaryContainer: Color(0xFF4A3A22),
    onSecondaryContainer: Color(0xFFF2E2C9),
    tertiary: Color(0xFFE8A08C),
    onTertiary: Color(0xFF3A1109),
    surface: Color(0xFF1E211F),
    onSurface: Color(0xFFECE7DA),
    surfaceContainerHighest: Color(0xFF2A2E2B),
    onSurfaceVariant: Color(0xFFA7A296),
    outline: Color(0xFF3A3E3A),
    outlineVariant: Color(0xFF2F3330),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF3A0A08),
    surfaceTint: Colors.transparent,
  );

  return _buildBase(
    colorScheme: scheme,
    scaffoldColor: const Color(0xFF141715),
    fontFamily: fontFamily,
  );
}

ThemeData _buildBase({
  required ColorScheme colorScheme,
  required Color scaffoldColor,
  String? fontFamily,
}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    fontFamily: fontFamily,
  );
  final textTheme = base.textTheme.apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
    fontFamily: fontFamily,
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: systemOverlayStyleFor(scaffoldColor),
      toolbarHeight: 52,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.7)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: fontFamily),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: fontFamily),
      ),
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      side: BorderSide(color: colorScheme.outline),
      shape: const StadiumBorder(),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(fontSize: 13, color: colorScheme.onSurface, fontFamily: fontFamily),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withValues(alpha: 0.6),
      thickness: 0.6,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}

/// 启动时的字体选择：Web 用打包字体，Windows 用系统雅黑，其余交给系统。
String? appFontFamily() {
  if (kIsWeb) return kWebFontFamily;
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return 'Microsoft YaHei UI';
  }
  return null;
}
