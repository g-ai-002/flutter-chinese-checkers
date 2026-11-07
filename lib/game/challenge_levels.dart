import 'board_geometry.dart';

enum ChallengeTier {
  starter('入门'),
  advanced('进阶'),
  master('大师');

  const ChallengeTier(this.label);

  final String label;
}

/// 一道残局：固定局面、目标营地、步数预算与参考解法。
///
/// 己方棋子用 0 号座位，对手营地不放活子；
/// 障碍子用 1 号座位，只做跳板，永远不轮到它走。
class ChallengeLevel {
  const ChallengeLevel({
    required this.id,
    required this.name,
    required this.hint,
    required this.tier,
    required this.parMoves,
    required this.moveLimit,
    required this.human,
    this.blockers = const [],
    required this.solution,
  });

  final String id;
  final String name;
  final String hint;
  final ChallengeTier tier;

  /// 三星步数：按参考解法走即可达成。
  final int parMoves;

  final int moveLimit;

  /// 己方棋子（不含已填满的营地内圈）。
  final List<(int, int)> human;

  /// 障碍棋子坐标，可被跨越但不会移动。
  final List<(int, int)> blockers;

  /// 参考解法，每一步为（起点 q、起点 r、终点 q、终点 r）。
  final List<(int, int, int, int)> solution;

  /// 生成对局初始局面：0 为己方，1 为障碍。
  List<int> cellsFor(BoardGeometry geometry) {
    final cells = List<int>.filled(geometry.length, -1);
    for (final (q, r) in human) {
      cells[geometry.holeAt(q, r)!] = 0;
    }
    for (final (q, r) in blockers) {
      cells[geometry.holeAt(q, r)!] = 1;
    }
    return cells;
  }

  /// 参考解法对应的孔位下标，测试用它验证每道关卡可解。
  List<(int, int)> solutionHoles(BoardGeometry geometry) => [
    for (final (fromQ, fromR, toQ, toR) in solution)
      (geometry.holeAt(fromQ, fromR)!, geometry.holeAt(toQ, toR)!),
  ];

  /// 按完成步数评星：参考步数内三星，多两步以内两星，其余一星。
  int starsFor(int moves) {
    if (moves <= parMoves) return 3;
    if (moves <= parMoves + 2) return 2;
    return 1;
  }
}

/// 目标营地（3 号角）内圈固定填满，残局只留第一排四个空位。
const List<(int, int)> _kInnerCamp = [
  (-4, 6),
  (-3, 6),
  (-2, 6),
  (-4, 7),
  (-3, 7),
  (-4, 8),
];

ChallengeLevel _level({
  required String id,
  required String name,
  required String hint,
  required ChallengeTier tier,
  required int parMoves,
  required int moveLimit,
  required List<(int, int)> human,
  List<(int, int)> blockers = const [],
  required List<(int, int, int, int)> solution,
}) => ChallengeLevel(
  id: id,
  name: name,
  hint: hint,
  tier: tier,
  parMoves: parMoves,
  moveLimit: moveLimit,
  human: [..._kInnerCamp, ...human],
  blockers: blockers,
  solution: solution,
);

/// 九道残局，按难度分三档，每档三道。
final List<ChallengeLevel> kChallengeLevels = [
  _level(
    id: 'starter-1',
    name: '一眼归位',
    hint: '四个空位就在营地第一排，把外面的棋子依次送进去。',
    tier: ChallengeTier.starter,
    parMoves: 4,
    moveLimit: 8,
    human: const [(-4, 4), (-3, 4), (-2, 4), (-1, 4)],
    blockers: const [(0, 4)],
    solution: const [
      (-4, 4, -4, 5),
      (-3, 4, -3, 5),
      (-2, 4, -2, 5),
      (-1, 4, -1, 5),
    ],
  ),
  _level(
    id: 'starter-2',
    name: '两段推进',
    hint: '左侧两子要连走两步，右侧两子先落位。',
    tier: ChallengeTier.starter,
    parMoves: 6,
    moveLimit: 10,
    human: const [(-4, 3), (-3, 3), (-2, 4), (-1, 4)],
    blockers: const [(0, 4), (0, 3), (-2, 2)],
    solution: const [
      (-4, 3, -4, 4),
      (-4, 4, -4, 5),
      (-3, 3, -3, 4),
      (-3, 4, -3, 5),
      (-2, 4, -2, 5),
      (-1, 4, -1, 5),
    ],
  ),
  _level(
    id: 'starter-3',
    name: '中腹起步',
    hint: '底排四子各自沿直线推进，注意别在入口前挤成一团。',
    tier: ChallengeTier.starter,
    parMoves: 8,
    moveLimit: 12,
    human: const [(-4, 3), (-3, 3), (-2, 3), (-1, 3)],
    blockers: const [(-4, 2), (-1, 2), (0, 3), (0, 4)],
    solution: const [
      (-4, 3, -4, 4),
      (-4, 4, -4, 5),
      (-3, 3, -3, 4),
      (-3, 4, -3, 5),
      (-2, 3, -2, 4),
      (-2, 4, -2, 5),
      (-1, 3, -1, 4),
      (-1, 4, -1, 5),
    ],
  ),
  _level(
    id: 'advanced-1',
    name: '长驱直入',
    hint: '从第二排出发，四条通道各走各的，不要互相挡路。',
    tier: ChallengeTier.advanced,
    parMoves: 9,
    moveLimit: 13,
    human: const [(-3, 2), (-3, 3), (-2, 3), (-1, 3)],
    blockers: const [(-4, 1), (-3, 1), (-1, 2), (0, 3), (0, 4)],
    solution: const [
      (-3, 2, -4, 3),
      (-4, 3, -4, 4),
      (-4, 4, -4, 5),
      (-3, 3, -3, 4),
      (-3, 4, -3, 5),
      (-2, 3, -2, 4),
      (-2, 4, -2, 5),
      (-1, 3, -1, 4),
      (-1, 4, -1, 5),
    ],
  ),
  _level(
    id: 'advanced-2',
    name: '分道而行',
    hint: '左路三步、中路两步，先让远处的棋子动身。',
    tier: ChallengeTier.advanced,
    parMoves: 8,
    moveLimit: 12,
    human: const [(-4, 2), (-3, 2), (-2, 4), (-1, 4)],
    blockers: const [(-4, 1), (-2, 2), (0, 3), (0, 4)],
    solution: const [
      (-4, 2, -4, 3),
      (-4, 3, -4, 4),
      (-4, 4, -4, 5),
      (-3, 2, -3, 3),
      (-3, 3, -3, 4),
      (-3, 4, -3, 5),
      (-2, 4, -2, 5),
      (-1, 4, -1, 5),
    ],
  ),
  _level(
    id: 'advanced-3',
    name: '高低错落',
    hint: '一枚棋子走三步，其余各走一至两步，先走远子。',
    tier: ChallengeTier.advanced,
    parMoves: 7,
    moveLimit: 11,
    human: const [(-4, 2), (-3, 3), (-2, 4), (-1, 4)],
    blockers: const [(-4, 1), (-3, 2), (-2, 3), (0, 3), (0, 4)],
    solution: const [
      (-4, 2, -4, 3),
      (-4, 3, -4, 4),
      (-4, 4, -4, 5),
      (-3, 3, -3, 4),
      (-3, 4, -3, 5),
      (-2, 4, -2, 5),
      (-1, 4, -1, 5),
    ],
  ),
  _level(
    id: 'master-1',
    name: '四阶接力',
    hint: '每枚棋子都要走完整条通道，先后顺序决定成败。',
    tier: ChallengeTier.master,
    parMoves: 10,
    moveLimit: 14,
    human: const [(-4, 1), (-3, 2), (-2, 3), (-1, 4)],
    blockers: const [(-4, 0), (-2, 2), (-2, 1), (-1, 2)],
    solution: const [
      (-4, 1, -4, 2),
      (-4, 2, -4, 3),
      (-4, 3, -4, 4),
      (-4, 4, -4, 5),
      (-3, 2, -3, 3),
      (-3, 3, -3, 4),
      (-3, 4, -3, 5),
      (-2, 3, -2, 4),
      (-2, 4, -2, 5),
      (-1, 4, -1, 5),
    ],
  ),
  _level(
    id: 'master-2',
    name: '双线并进',
    hint: '一条五步长线、一条三步中线、两枚近子收尾。',
    tier: ChallengeTier.master,
    parMoves: 11,
    moveLimit: 15,
    human: const [(-4, 0), (-2, 2), (-3, 3), (-1, 4)],
    blockers: const [(-3, 1), (-3, 2), (-1, 2), (0, 3), (0, 4)],
    solution: const [
      (-4, 0, -4, 1),
      (-4, 1, -4, 2),
      (-4, 2, -4, 3),
      (-4, 3, -4, 4),
      (-4, 4, -4, 5),
      (-2, 2, -2, 3),
      (-2, 3, -2, 4),
      (-2, 4, -2, 5),
      (-3, 3, -3, 4),
      (-3, 4, -3, 5),
      (-1, 4, -1, 5),
    ],
  ),
  _level(
    id: 'master-3',
    name: '六步登顶',
    hint: '最长的一条通道要走四步，先让远子动身，再补近子。',
    tier: ChallengeTier.master,
    parMoves: 12,
    moveLimit: 16,
    human: const [(-4, 0), (-3, 1), (-2, 3), (-1, 4)],
    blockers: const [(-2, 2), (-2, 1), (-1, 2), (0, 3), (0, 4)],
    solution: const [
      (-4, 0, -4, 1),
      (-4, 1, -4, 2),
      (-4, 2, -4, 3),
      (-4, 3, -4, 4),
      (-4, 4, -4, 5),
      (-3, 1, -3, 2),
      (-3, 2, -3, 3),
      (-3, 3, -3, 4),
      (-3, 4, -3, 5),
      (-2, 3, -2, 4),
      (-2, 4, -2, 5),
      (-1, 4, -1, 5),
    ],
  ),
];

ChallengeLevel? challengeById(String id) {
  for (final level in kChallengeLevels) {
    if (level.id == id) return level;
  }
  return null;
}

/// 关卡在列表中的序号（0 起），未知关卡返回 -1。
int challengeIndexOf(ChallengeLevel level) =>
    kChallengeLevels.indexWhere((item) => item.id == level.id);

ChallengeLevel? challengeAfter(ChallengeLevel level) {
  final index = challengeIndexOf(level);
  if (index < 0 || index + 1 >= kChallengeLevels.length) return null;
  return kChallengeLevels[index + 1];
}
