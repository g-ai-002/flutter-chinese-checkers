import '../game/challenge_levels.dart';

enum PlayMode {
  vsAi('人机对战'),
  local('同屏对战');

  const PlayMode(this.label);

  final String label;

  /// 严格按名称查找，未知名称返回 null（用于校验外部数据）。
  static PlayMode? tryByName(Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

enum Difficulty {
  easy('入门', '随机挑一步能走通的棋'),
  normal('普通', '优先向前推进，能连跳就连跳'),
  hard('高手', '多步搜索配合收官计划，会主动封堵对手进营');

  const Difficulty(this.label, this.description);

  final String label;
  final String description;

  static Difficulty byName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return Difficulty.normal;
  }
}

/// 逻辑更新速率：渲染跟随屏幕刷新，逻辑按固定步长推进。
enum LogicRate {
  hz30(30, '省电优先，低端设备更稳'),
  hz60(60, '性能与流畅度平衡'),
  hz120(120, '高刷屏动画最顺滑');

  const LogicRate(this.hz, this.description);

  final int hz;
  final String description;

  /// 默认 60Hz：多数屏幕的刷新率，兼顾性能与手感。
  static const LogicRate defaultRate = LogicRate.hz60;

  String get label => '$hz Hz';

  double get stepSeconds => 1 / hz;

  /// 未知或缺失的保存值回退到默认速率。
  static LogicRate byHz(int? hz) =>
      values.firstWhere((rate) => rate.hz == hz, orElse: () => defaultRate);
}

/// 可选玩家人数，每个阵营占据棋盘六个角中的一个。
enum PlayerCount {
  two(2, '2 人', [0, 3]),
  three(3, '3 人', [0, 2, 4]),
  four(4, '4 人', [0, 1, 3, 4]),
  six(6, '6 人', [0, 1, 2, 3, 4, 5]);

  const PlayerCount(this.count, this.label, this.seatArms);

  final int count;
  final String label;

  /// 每个座位对应的营地（棋盘六个角之一），两两相对时对局最公平。
  final List<int> seatArms;

  static PlayerCount byCount(int? count) =>
      tryByCount(count) ?? PlayerCount.two;

  /// 严格按人数查找，未知人数返回 null（用于校验外部数据）。
  static PlayerCount? tryByCount(int? count) {
    for (final value in values) {
      if (value.count == count) return value;
    }
    return null;
  }
}

/// 一局对局的设置，进入对局页后不再改变。
class GameSetup {
  const GameSetup({
    required this.mode,
    required this.playerCount,
    this.difficulty = Difficulty.normal,
    this.humanSeat = 0,
    this.challenge,
  });

  final PlayMode mode;
  final PlayerCount playerCount;
  final Difficulty difficulty;

  /// 人机模式下人类执子方；同屏模式不使用。
  final int humanSeat;

  /// 非空时进入残局挑战：固定局面、单人走子、限步完成。
  final ChallengeLevel? challenge;

  /// 残局使用双人座位表把己方营地转到下方，但只有 0 号座位走子。
  factory GameSetup.forChallenge(ChallengeLevel level) => GameSetup(
    mode: PlayMode.vsAi,
    playerCount: PlayerCount.two,
    challenge: level,
  );

  int get players => playerCount.count;

  List<int> get seatArms => playerCount.seatArms;

  bool get isChallenge => challenge != null;

  bool isAi(int seat) =>
      !isChallenge && mode == PlayMode.vsAi && seat != humanSeat;

  bool isHuman(int seat) =>
      isChallenge || mode == PlayMode.local || seat == humanSeat;

  int targetArmOf(int seat) => (seatArms[seat] + 3) % 6;

  String seatLabel(int seat) {
    if (isChallenge) return '你';
    final suffix = switch (mode) {
      PlayMode.local => '玩家 ${seat + 1}',
      PlayMode.vsAi => seat == humanSeat ? '你' : '电脑 ${seat + 1}',
    };
    return suffix;
  }
}

/// 对局结果的短标签：人机局为「胜 / 负 / 平局」，同屏局带上获胜玩家。
extension GameOutcomeLabel on GameSetup {
  String outcomeLabelFor(int? winner) {
    if (winner == null) return '平局';
    if (mode == PlayMode.vsAi) return winner == humanSeat ? '胜' : '负';
    return '${seatLabel(winner)}胜';
  }
}
