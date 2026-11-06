/// 对局模式。
enum PlayMode {
  vsAi('人机对战'),
  local('同屏对战');

  const PlayMode(this.label);

  final String label;
}

/// 电脑难度。
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

  static PlayerCount byCount(int? count) {
    for (final value in values) {
      if (value.count == count) return value;
    }
    return PlayerCount.two;
  }
}

/// 一局对局的设置，进入对局页后不再改变。
class GameSetup {
  const GameSetup({
    required this.mode,
    required this.playerCount,
    this.difficulty = Difficulty.normal,
    this.humanSeat = 0,
  });

  final PlayMode mode;
  final PlayerCount playerCount;
  final Difficulty difficulty;

  /// 人机模式下人类执子方；同屏模式不使用。
  final int humanSeat;

  int get players => playerCount.count;

  List<int> get seatArms => playerCount.seatArms;

  bool isAi(int seat) => mode == PlayMode.vsAi && seat != humanSeat;

  bool isHuman(int seat) => mode == PlayMode.local || seat == humanSeat;

  /// 目标营地：正对面的角。
  int targetArmOf(int seat) => (seatArms[seat] + 3) % 6;

  String seatLabel(int seat) {
    final suffix = switch (mode) {
      PlayMode.local => '玩家 ${seat + 1}',
      PlayMode.vsAi => seat == humanSeat ? '你' : '电脑 ${seat + 1}',
    };
    return suffix;
  }
}
