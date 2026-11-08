import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../game/board_geometry.dart';

/// 对局页布局：棋盘居中，提示信息分列上方与左右，操作按钮固定在下方。
///
/// - 竖屏（棋盘占满宽度）：轮次与进度收进上下信息带，棋盘在中间居中，
///   操作坞与进度面板共处棋盘下方的一行；
/// - 横屏与桌面（棋盘占满高度）：轮次与进度贴棋盘左侧，工具贴右侧，
///   操作坞落在棋盘右下方的空角；
/// - 窗口接近棋盘比例时退化为四角浮层，并用孔位几何校验保证不压棋子；
/// - 极端尺寸才让棋盘缩进信息带之间。
///
/// 尺寸只由窗口大小决定，轮次、进度与思考指示器变化都不会移动棋盘。
class GameLayout {
  const GameLayout._({
    required this.boardInsets,
    required this.left,
    required this.rightTop,
    required this.top,
    required this.bottom,
    required this.hudWidth,
    required this.titleWidth,
    required this.progressWidth,
    required this.progressLeft,
    required this.dockLeft,
    required this.dense,
    required this.compactDock,
    required this.progressButton,
  });

  /// 棋盘上下需要避让的高度；为零表示棋盘铺满整屏。
  final EdgeInsets boardInsets;

  /// 标题与轮次浮层的左边缘。
  final double left;

  /// 工具浮层距右边缘的距离。
  final double rightTop;

  final double top;
  final double bottom;
  final double hudWidth;
  final double titleWidth;
  final double progressWidth;

  /// 进度面板左边缘，通常与操作坞同处棋盘下方一行。
  final double progressLeft;

  /// 操作坞左边缘。
  final double dockLeft;

  /// 矮窗口：轮次只保留主标题。
  final bool dense;

  final bool compactDock;

  /// 进度面板放不下时改为按钮，点击弹出完整进度。
  final bool progressButton;

  static const double _margin = 10;
  static const double _gap = 8;
  static const double _minWidth = 136;
  static const double _compactDock = 136;
  static const double _dockHeight = 50;
  static const double _progressButton = 42;

  /// 以 1.3 倍字号（HUD 字号上限）估算的标题行高度。
  static const double _titleStack = 46 + _gap;

  static final BoardGeometry _geometry = BoardGeometry.star();

  factory GameLayout.resolve({
    required Size size,
    required bool challenge,
    required int players,
    required bool showProgressTitle,
  }) {
    final scale = math.min(size.width / 14, size.height / 16);
    final boardWidth = 14 * scale;
    final boardHeight = 16 * scale;
    final center = size.center(Offset.zero);
    final pad = scale * 0.44 + 3;
    final holes = _geometry.holes;

    /// 浮层矩形是否压到任何孔位（含棋子半径与 3px 间隙）。
    bool clear(Rect rect) {
      for (final hole in holes) {
        final point = center + Offset(hole.x * scale, hole.y * scale);
        if (rect.inflate(pad).contains(point)) return false;
      }
      return true;
    }

    final showProgress = !challenge;
    final progressHeight = 26.0 * players + 16 + (showProgressTitle ? 22 : 0);
    final progressWidth = showProgressTitle ? 148.0 : 132.0;
    final dockFull = challenge ? 162.0 : 238.0;
    final rightWidth = challenge ? 112.0 : 104.0;

    double stackHeight(bool dense) => _titleStack + (challenge ? 74 : (dense ? 46 : 70));
    double topNeed(bool dense) => 8 + stackHeight(dense) + 6;
    double bottomNeed(bool button) =>
        _margin +
        (button || !showProgress ? _dockHeight : math.max(_dockHeight, progressHeight)) +
        6;
    double dockWidth(bool compact) => compact ? _compactDock : dockFull;

    /// 左贴 [margin]、给定高度区间内可用的最大宽度（避开孔位）。
    double fitWidth(double top, double height, {double cap = 230}) {
      var edge = _margin + cap;
      for (final hole in holes) {
        final point = center + Offset(hole.x * scale, hole.y * scale);
        if (point.dy < top - pad || point.dy > top + height + pad) continue;
        edge = math.min(edge, point.dx - pad);
      }
      return edge - _margin;
    }

    var dense = size.height < 700;
    var progressButton = false;
    var rails = false;
    var compactDock = false;
    var insets = EdgeInsets.zero;
    var hudWidth = 230.0;
    var titleWidth = 230.0;
    var left = _margin;
    var rightTop = _margin;
    var progressLeft = _margin;
    var dockLeft = _margin;
    var dockRight = _margin;
    const top = 8.0;
    const bottom = _margin;

    Rect stackAt(double x, double width) => Rect.fromLTWH(x, top, width, stackHeight(dense));
    Rect progressAt(double x) =>
        Rect.fromLTWH(x, size.height - _margin - progressHeight, progressWidth, progressHeight);
    Rect dockAt(double right, bool compact) => Rect.fromLTWH(
      size.width - right - dockWidth(compact),
      size.height - _margin - _dockHeight,
      dockWidth(compact),
      _dockHeight,
    );

    /// 四角浮层：收窄标题浮层直到不压棋子，进度面板放不下就收成按钮。
    void overlay() {
      var fitted = fitWidth(top, stackHeight(dense));
      if (fitted < _minWidth && !dense) {
        dense = true;
        fitted = fitWidth(top, stackHeight(true));
      }
      hudWidth = fitted >= _minWidth ? fitted : _minWidth;
      progressButton = showProgress && !clear(progressAt(_margin));
      insets = EdgeInsets.zero;
    }

    /// 棋盘下方的一行：进度面板（或按钮）在左，操作坞在右，整体居中。
    void placeBottomRow() {
      final slot = showProgress ? (progressButton ? _progressButton : progressWidth) : 0.0;
      final gap = slot > 0 ? _gap : 0.0;
      var row = slot + gap + dockWidth(compactDock);
      if (row > size.width - _margin * 2 && !compactDock) {
        compactDock = true;
        row = slot + gap + dockWidth(true);
      }
      if (row > size.width - _margin * 2 && !progressButton) {
        progressButton = true;
        row = _progressButton + _gap + dockWidth(compactDock);
      }
      progressLeft = math.max(_margin, (size.width - row) / 2);
      dockLeft = progressLeft + (showProgress ? slot + gap : 0);
    }

    if (boardWidth >= size.width - 0.5) {
      // 棋盘占满宽度：上下信息带 + 中间棋盘。
      final free = size.height - boardHeight;
      hudWidth = math.min(230.0, math.max(150.0, size.width - 20 - rightWidth - 10));
      if (free >= topNeed(dense) + bottomNeed(false)) {
        insets = EdgeInsets.only(top: topNeed(dense), bottom: bottomNeed(false));
      } else if (free >= topNeed(true) + bottomNeed(false)) {
        dense = true;
        insets = EdgeInsets.only(top: topNeed(dense), bottom: bottomNeed(false));
      } else if (free >= topNeed(true) + bottomNeed(true)) {
        dense = true;
        progressButton = true;
        insets = EdgeInsets.only(top: topNeed(dense), bottom: bottomNeed(true));
      } else if (fitWidth(top, stackHeight(true)) >= _minWidth) {
        // 信息带放不下整块棋盘：改用四角浮层，棋盘保持整块。
        overlay();
      } else {
        // 极矮窗口：棋盘缩进信息带之间，仍不遮挡任何棋子。
        dense = true;
        progressButton = true;
        insets = EdgeInsets.only(top: topNeed(true), bottom: bottomNeed(true));
      }
    } else {
      // 棋盘占满高度：信息贴到棋盘左右两侧。
      final sideGap = (size.width - boardWidth) / 2;
      final railWidth = math.min(230.0, sideGap - _gap * 2);
      final railLeft = math.max(_margin, sideGap - railWidth - _gap);
      if (railWidth >= _minWidth && clear(stackAt(railLeft, railWidth))) {
        rails = true;
        hudWidth = railWidth;
        left = railLeft;
        rightTop = math.max(_margin, sideGap - rightWidth - _gap);
        compactDock = !clear(dockAt(math.max(_margin, sideGap - dockFull - _gap), false));
        dockRight = math.max(_margin, sideGap - dockWidth(compactDock) - _gap);
        progressButton = showProgress && !clear(progressAt(railLeft));
        titleWidth = math.max(
          hudWidth,
          math.min(300.0, size.width - railLeft - rightTop - 112 - _gap),
        );
        progressLeft = railLeft;
        dockLeft = size.width - dockRight - dockWidth(compactDock);
      } else {
        overlay();
      }
    }

    if (!rails) {
      titleWidth = hudWidth;
      if (insets.bottom >= _dockHeight + _margin) {
        // 棋盘下方留出了信息带：进度与操作坞共用居中一行。
        placeBottomRow();
      } else {
        // 棋盘铺满高度、只剩四角空位：进度贴左下，操作坞贴右下。
        compactDock = !clear(dockAt(_margin, false));
        dockLeft = size.width - _margin - dockWidth(compactDock);
        progressButton = showProgress && !clear(progressAt(_margin));
      }
    }
    return GameLayout._(
      boardInsets: insets,
      left: left,
      rightTop: rightTop,
      top: top,
      bottom: bottom,
      hudWidth: hudWidth,
      titleWidth: titleWidth,
      progressWidth: progressWidth,
      progressLeft: progressLeft,
      dockLeft: dockLeft,
      dense: dense,
      compactDock: compactDock,
      progressButton: progressButton,
    );
  }
}
