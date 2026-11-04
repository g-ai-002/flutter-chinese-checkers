/// Web 端字体：CanvasKit 没有系统中文字体回退，使用 soup_fonts 的思源黑体。
const String kWebFontFamily = 'SourceHanSansCN';

/// 中文标题字体回退链，Windows 优先使用系统自带的雅黑。
const List<String> kTitleFontFallback = [
  'Microsoft YaHei UI',
  'SourceHanSansCN',
  'Noto Sans CJK SC',
];

class AppConstants {
  AppConstants._();

  static const String appName = '中国跳棋';
  static const String version = '0.1.1';

  /// 用户目录下的应用文件夹，日志与导出文件都放在这里。
  static const String appDirName = 'FlutterTiaoqi';

  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeySound = 'sound_enabled';
  static const String prefKeyMusic = 'music_enabled';
  static const String prefKeyHaptics = 'haptics_enabled';
  static const String prefKeyShowHints = 'show_hints';
  static const String prefKeyBoardTheme = 'board_theme';
  static const String prefKeyPlayerCount = 'player_count';
  static const String prefKeyDifficulty = 'difficulty';
  static const String prefKeyHumanSeat = 'human_seat';
}
