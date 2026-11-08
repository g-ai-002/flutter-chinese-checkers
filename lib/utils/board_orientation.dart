import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'platform_info.dart';

/// 窄屏横竖屏策略：网格更适合横屏时才旋转并全屏，否则保持竖屏。
///
/// 六角星棋盘是 14:16 的竖高网格，旋转到横屏后棋盘反而变小，
/// 因此手机与折叠屏折叠态都保持竖屏；换成更宽的网格即可自动横屏。
class BoardOrientation {
  BoardOrientation._();

  static const double boardAspect = 14 / 16;

  /// 最短边小于该值视为窄屏（手机、折叠屏折叠态）。
  static const double narrowLimit = 600;

  /// 横屏棋盘面积至少领先这么多才旋转，避免临界尺寸来回抖动。
  static const double minGain = 0.04;

  static const List<DeviceOrientation> portraitOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];

  static const List<DeviceOrientation> landscapeOrientations = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static const List<DeviceOrientation> allOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// 给定窗口里棋盘能拿到的最大尺寸。
  static Size boardSize(Size window, {double aspect = boardAspect}) {
    final width = math.min(window.width, window.height * aspect);
    return Size(width, width / aspect);
  }

  static double _area(Size window, double aspect) {
    final size = boardSize(window, aspect: aspect);
    return size.width * size.height;
  }

  /// 竖屏窗口旋转到横屏后棋盘是否明显更大。
  static bool prefersLandscape(Size window, {double aspect = boardAspect}) {
    if (window.width >= window.height) return false;
    if (window.shortestSide >= narrowLimit) return false;
    final flipped = Size(window.height, window.width);
    return _area(flipped, aspect) > _area(window, aspect) * (1 + minGain);
  }

  static List<DeviceOrientation>? _applied;
  static bool _immersive = false;

  /// 窄屏锁定到判定方向，宽屏恢复自由旋转；重复调用不会重复请求平台。
  static void apply(Size window) {
    if (!isMobilePlatform) return;
    final narrow = window.shortestSide < narrowLimit;
    final landscape = narrow && prefersLandscape(window);
    final target = !narrow
        ? allOrientations
        : (landscape ? landscapeOrientations : portraitOrientations);
    if (identical(_applied, target) && _immersive == landscape) return;
    _applied = target;
    _immersive = landscape;
    unawaited(SystemChrome.setPreferredOrientations(target));
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
  }

  /// 离开对局页后交还方向控制，避免把锁定状态带到其他页面。
  static void restore() {
    if (!isMobilePlatform || _applied == null) return;
    reset();
    unawaited(SystemChrome.setPreferredOrientations(allOrientations));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  @visibleForTesting
  static void reset() {
    _applied = null;
    _immersive = false;
  }
}
