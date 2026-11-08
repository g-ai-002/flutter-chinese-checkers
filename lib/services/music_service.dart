import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'log_service.dart';
import 'music_synth.dart';

/// 背景音乐：运行时合成五声音阶循环，与音效共用 SoLoud 音频引擎。
///
/// Web 端的自动播放限制会在用户首次点击页面后重试；应用进入后台时暂停，
/// 回到前台继续，避免无谓的音频占用。
class MusicService {
  MusicService._();

  static const double _volume = 0.22;

  static bool enabled = true;

  /// 测试注入的播放出口，非空时不再触碰平台播放器。
  @visibleForTesting
  static void Function(bool enabled)? sink;

  static AudioSource? _source;
  static SoundHandle? _handle;
  static Future<void>? _starting;
  static bool _failed = false;
  static bool _suspended = false;

  /// 启动背景音乐；未启用、已暂停或正在播放时直接返回。
  static Future<void> start() async {
    if (!enabled || _suspended) return;
    final target = sink;
    if (target != null) {
      target(true);
      return;
    }
    if (!_failed && _handle != null && SoLoud.instance.getIsValidVoiceHandle(_handle!)) {
      return;
    }
    final starting = _starting;
    if (starting != null) return starting;
    final future = _start();
    _starting = future;
    try {
      await future;
    } finally {
      if (identical(_starting, future)) _starting = null;
    }
  }

  static Future<void> _start() async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) await soloud.init();
      final source = _source;
      if (source == null) {
        final clip = await synthesizeMusicInBackground();
        _source = await soloud.loadMem('tiaoqi-bgm.wav', clip);
      }
    } catch (error) {
      _failed = true;
      debugPrint('[MusicService] 背景音乐加载失败: $error');
      LogService.warning('背景音乐加载失败: $error');
      return;
    }
    if (!enabled || _suspended) return;
    try {
      _handle = SoLoud.instance.play(_source!, volume: _volume, looping: true);
      LogService.info('背景音乐开始播放');
    } catch (error) {
      // 浏览器未获得用户手势时可能拒绝播放，保留音源等待下一次点击重试。
      debugPrint('[MusicService] 背景音乐等待用户操作: $error');
    }
  }

  static Future<void> setEnabled(bool value) async {
    enabled = value;
    final target = sink;
    if (target != null) {
      target(value);
      return;
    }
    if (!value) {
      _suspended = false;
      await _stop();
      return;
    }
    _suspended = false;
    await start();
  }

  /// 首次用户操作后重试播放，用于绕过 Web 自动播放限制。
  static void retryOnInteraction() {
    if (!enabled || _suspended) return;
    unawaited(start());
  }

  static void pauseForLifecycle() {
    _suspended = true;
    final handle = _handle;
    if (handle == null || !SoLoud.instance.isInitialized) return;
    try {
      SoLoud.instance.setPause(handle, true);
    } catch (_) {
      // 播放器未就绪时无需处理。
    }
  }

  static void resumeForLifecycle() {
    if (!enabled) return;
    _suspended = false;
    final handle = _handle;
    if (handle != null &&
        SoLoud.instance.isInitialized &&
        SoLoud.instance.getIsValidVoiceHandle(handle)) {
      try {
        SoLoud.instance.setPause(handle, false);
        return;
      } catch (_) {
        // 句柄失效时退回重新播放。
      }
    }
    unawaited(start());
  }

  /// 应用退出时彻底停止播放，不留后台音频任务。
  static Future<void> stopForShutdown() async {
    _suspended = false;
    await _stop();
  }

  static Future<void> _stop() async {
    final handle = _handle;
    _handle = null;
    if (handle == null) return;
    try {
      if (SoLoud.instance.isInitialized) await SoLoud.instance.stop(handle);
    } catch (_) {
      // 句柄已失效时无需再处理。
    }
  }

  @visibleForTesting
  static void reset() {
    sink = null;
    enabled = true;
    _source = null;
    _handle = null;
    _starting = null;
    _failed = false;
    _suspended = false;
  }
}
