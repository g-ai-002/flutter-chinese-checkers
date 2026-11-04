import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'log_service.dart';
import 'tone_synth.dart';

/// 交互反馈类型，决定提示音与震动的强弱。
enum GameSound { select, step, jump, win }

/// 落子、连跳与终局音效，全部在运行时合成，仓库不携带音频文件。
class SoundService {
  SoundService._();

  static bool soundEnabled = true;
  static bool hapticsEnabled = true;

  /// 测试注入的音频出口，非空时不再触碰平台播放器。
  @visibleForTesting
  static void Function(GameSound sound)? sink;

  static final Map<GameSound, AudioSource> _sources = {};
  static final Map<GameSound, Uint8List> _clips = {};
  static Future<void>? _loading;
  static bool _loadFailed = false;

  static const Map<GameSound, List<SynthNote>> _presets = {
    GameSound.select: [
      SynthNote(frequency: 820, start: 0, duration: 0.045, gain: 0.35),
      SynthNote(
        frequency: 1240,
        start: 0.002,
        duration: 0.035,
        gain: 0.18,
        noise: 0.05,
      ),
    ],
    GameSound.step: [
      SynthNote(frequency: 1080, start: 0, duration: 0.05, noise: 0.18),
      SynthNote(
        frequency: 690,
        start: 0.004,
        duration: 0.075,
        gain: 0.32,
        noise: 0.06,
      ),
    ],
    GameSound.jump: [
      SynthNote(frequency: 620, start: 0, duration: 0.07, gain: 0.42),
      SynthNote(frequency: 830, start: 0.055, duration: 0.08, gain: 0.45),
      SynthNote(
        frequency: 1180,
        start: 0.115,
        duration: 0.1,
        gain: 0.38,
        noise: 0.1,
      ),
    ],
    GameSound.win: [
      SynthNote(frequency: 523.25, start: 0, duration: 0.16),
      SynthNote(frequency: 659.25, start: 0.12, duration: 0.16),
      SynthNote(frequency: 783.99, start: 0.24, duration: 0.2),
      SynthNote(frequency: 1046.5, start: 0.4, duration: 0.4, gain: 0.45),
    ],
  };

  static void configure({required bool sound, required bool haptics}) {
    soundEnabled = sound;
    hapticsEnabled = haptics;
  }

  /// 预合成音效并载入 SoLoud 音源；失败时保持静默，不影响对局。
  static Future<void> init() => _ensureLoaded();

  static Future<void> _ensureLoaded() {
    if (_loadFailed || _sources.isNotEmpty) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) await soloud.init();
      for (final sound in GameSound.values) {
        _sources[sound] = await soloud.loadMem(
          'tiaoqi-${sound.name}.wav',
          clipOf(sound),
        );
      }
    } catch (error) {
      _loadFailed = true;
      _disposeAll();
      debugPrint('[SoundService] 音效初始化失败，已静音: $error');
      LogService.warning('音效初始化失败，已静音: $error');
    }
  }

  /// 某个反馈对应的合成音频，供测试校验音效配方。
  @visibleForTesting
  static Uint8List clipOf(GameSound sound) =>
      _clips.putIfAbsent(sound, () => synthesizeWav(_presets[sound]!));

  static void play(GameSound sound) {
    if (soundEnabled) {
      final target = sink;
      if (target != null) {
        target(sound);
      } else {
        unawaited(_play(sound));
      }
    }
    if (!hapticsEnabled) return;
    final haptic = switch (sound) {
      GameSound.select => HapticFeedback.selectionClick,
      GameSound.step => HapticFeedback.lightImpact,
      GameSound.jump => HapticFeedback.mediumImpact,
      GameSound.win => HapticFeedback.vibrate,
    };
    haptic();
  }

  static Future<void> _play(GameSound sound) async {
    try {
      await _ensureLoaded();
      final source = _sources[sound];
      if (source == null) return;
      final soloud = SoLoud.instance;
      soloud.stopAudioSource(source);
      soloud.play(source);
    } catch (error) {
      debugPrint('[SoundService] 播放失败: $error');
    }
  }

  static void _disposeAll() {
    final sources = _sources.values.toList();
    _sources.clear();
    for (final source in sources) {
      unawaited(_dispose(source));
    }
  }

  static Future<void> _dispose(AudioSource source) async {
    try {
      await SoLoud.instance.disposeSource(source);
    } catch (_) {
      // 音源已失效时无需再处理。
    }
  }

  @visibleForTesting
  static void reset() {
    sink = null;
    _disposeAll();
    _clips.clear();
    _loading = null;
    _loadFailed = false;
    soundEnabled = true;
    hapticsEnabled = true;
  }
}
