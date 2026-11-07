/// Web 端字体：CanvasKit 没有系统中文字体回退，使用 soup_fonts 的思源黑体。
const String kWebFontFamily = 'SourceHanSansCN';

/// 首页切换「棋盘 + 文案」并排布局的宽度。
const double kHomeWideBreakpoint = 780;

/// 首页加宽左右留白的宽度。
const double kHomePaddingBreakpoint = 900;

const double kGameWideBreakpoint = 920;

class AppConstants {
  AppConstants._();

  static const String appName = '中国跳棋';
  static const String version = '0.6.3';

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
  static const String prefKeyLogicRate = 'logic_rate';
  static const String prefKeyMatches = 'match_history';
  static const String prefKeyReplays = 'replay_archive';
  static const String prefKeyChallenges = 'challenge_progress';

  /// 偏好存储里保留的对局摘要上限，避免历史无限增长。
  static const int maxStoredMatches = 60;

  /// 棋谱库保留的完整棋谱上限，避免偏好存储随对局数量膨胀。
  static const int maxStoredReplays = 20;
}
