import 'package:chinese_checkers/game/board_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BoardGeometry geometry;

  setUp(() {
    geometry = BoardGeometry.star();
  });

  test('六角星共有 121 个孔位，中央 61 个，六个营地各 10 个', () {
    expect(geometry.length, 121);
    expect(geometry.armHoles, hasLength(6));
    for (final arm in geometry.armHoles) {
      expect(arm, hasLength(10));
    }
    final center = geometry.holes.where((hole) => hole.arm < 0).length;
    expect(center, 61);
    expect(geometry.isComplete, isTrue);
  });

  test('每行孔数与经典棋盘一致', () {
    final counts = <int, int>{};
    for (final hole in geometry.holes) {
      counts[hole.r] = (counts[hole.r] ?? 0) + 1;
    }
    final rows = [for (var r = -8; r <= 8; r++) counts[r] ?? 0];
    expect(rows, [1, 2, 3, 4, 13, 12, 11, 10, 9, 10, 11, 12, 13, 4, 3, 2, 1]);
  });

  test('孔位编号唯一且相邻关系对称', () {
    final keys = <String>{};
    for (final hole in geometry.holes) {
      keys.add('${hole.q},${hole.r}');
    }
    expect(keys, hasLength(121));
    for (var hole = 0; hole < geometry.length; hole++) {
      for (final neighbor in geometry.neighbors[hole]) {
        expect(geometry.neighbors[neighbor], contains(hole));
        expect(geometry.distance(hole, neighbor), 1);
      }
    }
  });

  test('绕中心旋转 60 度后棋盘保持不变', () {
    for (final hole in geometry.holes) {
      var q = hole.q;
      var r = hole.r;
      for (var turn = 0; turn < 6; turn++) {
        final nextQ = -r;
        final nextR = q + r;
        q = nextQ;
        r = nextR;
        expect(geometry.holeAt(q, r), isNotNull);
      }
      expect(geometry.holeAt(q, r), geometry.holeAt(hole.q, hole.r));
    }
  });

  test('六个营地互不重叠，正对面营地相距 16', () {
    final seen = <int>{};
    for (final arm in geometry.armHoles) {
      for (final hole in arm) {
        expect(seen.add(hole), isTrue);
      }
    }
    for (var arm = 0; arm < 6; arm++) {
      final opposite = geometry.oppositeArm(arm);
      expect(
        geometry.distance(geometry.tipHole(arm), geometry.tipHole(opposite)),
        16,
      );
      expect(geometry.armOf(geometry.tipHole(arm)), arm);
    }
  });

  test('0 号营地在正上方，3 号营地在正下方', () {
    final top = geometry.holes[geometry.tipHole(0)];
    final bottom = geometry.holes[geometry.tipHole(3)];
    expect(top.y, lessThan(0));
    expect(bottom.y, greaterThan(0));
    expect(top.x, closeTo(0, 1e-9));
    expect(bottom.x, closeTo(0, 1e-9));
  });

  test('到目标营地的距离表以营地孔位为 0', () {
    final distances = geometry.distancesToArm(3);
    for (final hole in geometry.armHoles[3]) {
      expect(distances[hole], 0);
    }
    for (var hole = 0; hole < geometry.length; hole++) {
      expect(distances[hole], lessThanOrEqualTo(16));
    }
  });

  test('六角星轮廓有 12 个顶点', () {
    final outline = BoardGeometry.starOutline();
    expect(outline, hasLength(12));
    expect(outline.first[1], lessThan(0));
  });
}
