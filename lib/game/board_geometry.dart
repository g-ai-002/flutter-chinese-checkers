import 'dart:math' as math;

/// 相邻孔位的轴向坐标偏移（尖顶六边形，行方向水平）。
const List<List<int>> kAxialDirections = [
  [1, 0],
  [-1, 0],
  [0, 1],
  [0, -1],
  [1, -1],
  [-1, 1],
];

const double _sqrt3Half = 0.8660254037844386;

/// 棋盘上的一个孔位。
///
/// [x]/[y] 是以孔距为 1 的模型坐标，绘制时再统一缩放。
class Hole {
  const Hole({required this.index, required this.q, required this.r, required this.arm});

  final int index;
  final int q;
  final int r;

  /// 所属营地（0-5），中央区域为 -1。
  final int arm;

  double get x => q + r / 2;
  double get y => r * _sqrt3Half;

  bool get inCamp => arm >= 0;
}

/// 121 孔六角星棋盘：中央边长为 5 的六边形（61 孔）与六个 10 孔三角营地。
///
/// 六个营地按顺时针排列，0 号在正上方；每个营地有正对面的目标营地。
class BoardGeometry {
  BoardGeometry._(this.holes, this.neighbors, this.armHoles, this._indexByKey);

  factory BoardGeometry.star() {
    final raw = <List<int>>[];

    void add(int q, int r, int arm) {
      raw.add([q, r, arm]);
    }

    // 中央六边形。
    for (var r = -4; r <= 4; r++) {
      for (var q = -4; q <= 4; q++) {
        if ((q + r).abs() <= 4) add(q, r, -1);
      }
    }

    // 正上方营地：4 + 3 + 2 + 1 个孔，沿 +r 方向逐行收窄。
    final topArm = <List<int>>[];
    for (var r = -8; r <= -5; r++) {
      for (var q = -4 - r; q <= 4; q++) {
        topArm.add([q, r]);
      }
    }
    for (var arm = 0; arm < 6; arm++) {
      for (final cell in topArm) {
        var q = cell[0];
        var r = cell[1];
        for (var turn = 0; turn < arm; turn++) {
          final nextQ = -r;
          final nextR = q + r;
          q = nextQ;
          r = nextR;
        }
        add(q, r, arm);
      }
    }

    // 按行、列排序，保证孔位编号稳定，便于测试与存档。
    raw.sort((a, b) {
      final byRow = a[1].compareTo(b[1]);
      return byRow != 0 ? byRow : a[0].compareTo(b[0]);
    });

    final holes = <Hole>[];
    final indexByKey = <int, int>{};
    for (var i = 0; i < raw.length; i++) {
      final cell = raw[i];
      holes.add(Hole(index: i, q: cell[0], r: cell[1], arm: cell[2]));
      indexByKey[_key(cell[0], cell[1])] = i;
    }

    final neighbors = List.generate(holes.length, (_) => <int>[]);
    final arms = List.generate(6, (_) => <int>[]);
    for (final hole in holes) {
      if (hole.arm >= 0) arms[hole.arm].add(hole.index);
      for (final dir in kAxialDirections) {
        final id = indexByKey[_key(hole.q + dir[0], hole.r + dir[1])];
        if (id != null) neighbors[hole.index].add(id);
      }
    }

    return BoardGeometry._(holes, neighbors, arms, indexByKey);
  }

  final List<Hole> holes;

  final List<List<int>> neighbors;

  final List<List<int>> armHoles;

  final Map<int, int> _indexByKey;

  int get length => holes.length;

  bool get isComplete => holes.length == 121 && armHoles.every((a) => a.length == 10);

  int? holeAt(int q, int r) => _indexByKey[_key(q, r)];

  int armOf(int hole) => holes[hole].arm;

  int oppositeArm(int arm) => (arm + 3) % 6;

  int distance(int a, int b) {
    final ha = holes[a];
    final hb = holes[b];
    final dq = ha.q - hb.q;
    final dr = ha.r - hb.r;
    return (dq.abs() + dr.abs() + (dq + dr).abs()) ~/ 2;
  }

  /// 从 [from] 沿 [direction] 走 [steps] 步的孔位，越界返回 null。
  int? step(int from, int direction, [int steps = 1]) {
    final hole = holes[from];
    final dir = kAxialDirections[direction];
    return _indexByKey[_key(hole.q + dir[0] * steps, hole.r + dir[1] * steps)];
  }

  /// 营地内最靠外的孔位，用于落点排序与 AI 评估。
  int tipHole(int arm) {
    var best = armHoles[arm].first;
    var bestDistance = 0;
    final origin = holeAt(0, 0)!;
    for (final hole in armHoles[arm]) {
      final d = distance(hole, origin);
      if (d > bestDistance) {
        bestDistance = d;
        best = hole;
      }
    }
    return best;
  }

  /// 每个孔位到指定营地最近孔位的距离表，AI 评估反复使用。
  List<int> distancesToArm(int arm) {
    final result = List<int>.filled(length, 0);
    for (var hole = 0; hole < length; hole++) {
      var best = 99;
      for (final target in armHoles[arm]) {
        final d = distance(hole, target);
        if (d < best) best = d;
      }
      result[hole] = best;
    }
    return result;
  }

  /// 六角星外轮廓的 12 个顶点（模型坐标），按角度依次排列。
  ///
  /// 六个角指向营地外侧，六个凹口位于中央六边形的角上。
  static List<List<double>> starOutline({double tip = 7.8, double notch = 4.8}) {
    final points = <List<double>>[];
    for (var i = 0; i < 12; i++) {
      final isTip = i.isEven;
      final radius = isTip ? tip : notch;
      final angle = math.pi / 2 - i * math.pi / 6;
      points.add([math.cos(angle) * radius, -math.sin(angle) * radius]);
    }
    return points;
  }

  static int _key(int q, int r) => (q + 16) * 64 + (r + 16);
}
