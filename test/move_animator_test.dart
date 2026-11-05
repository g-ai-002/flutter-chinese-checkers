import 'package:chinese_checkers/flame/move_animator.dart';
import 'package:chinese_checkers/game/checkers_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('单步与长连跳动画时长不超过 0.46 秒', () {
    final step = MoveAnimation(move: CheckersMove.step(0, 1), cells: const [1]);
    expect(step.duration, closeTo(0.16, 1e-9));

    final jump = MoveAnimation(
      move: CheckersMove.jump(0, const [2, 4, 6, 8, 10, 12, 14]),
      cells: const [0],
    );
    expect(jump.duration, closeTo(0.46, 1e-9));
  });

  test('连续着法按顺序播放，各自保留走完后的局面快照', () {
    final animator = MoveAnimator();
    final first = CheckersMove.step(0, 1);
    final second = CheckersMove.jump(1, const [3]);

    animator.enqueue(first, const [1]);
    animator.enqueue(second, const [2]);

    expect(animator.pending, 2);
    expect(animator.current!.move, first);
    expect(animator.current!.cells, const [1]);

    animator.advance(0.1);
    expect(animator.current!.move, first);

    // 第一手播完后剩余时间顺延给第二手，不会丢掉第二手。
    animator.advance(0.06);
    expect(animator.current!.move, second);
    expect(animator.current!.cells, const [2]);

    animator.advance(1);
    expect(animator.isAnimating, isFalse);
    expect(animator.current, isNull);
  });

  test('入队时复制快照，后续棋盘变化不影响已排队动画', () {
    final cells = [0, 1];
    final animator = MoveAnimator()..enqueue(CheckersMove.step(0, 1), cells);

    cells[0] = 9;

    expect(animator.current!.cells, const [0, 1]);
  });

  test('清空队列后不再播放任何动画', () {
    final animator = MoveAnimator()
      ..enqueue(CheckersMove.step(0, 1), const [1])
      ..clear();

    expect(animator.isAnimating, isFalse);
    expect(animator.pending, 0);
  });
}
