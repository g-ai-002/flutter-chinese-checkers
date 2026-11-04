import 'dart:typed_data';

import 'package:chinese_checkers/services/sound_service.dart';
import 'package:chinese_checkers/services/tone_synth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late List<GameSound> played;

  setUp(() {
    calls = [];
    played = [];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    SoundService.sink = played.add;
    SoundService.configure(sound: true, haptics: true);
  });

  tearDown(() {
    SoundService.sink = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    SoundService.reset();
  });

  List<String> hapticTypes() =>
      calls.map((call) => '${call.arguments}').toList();

  List<String> hapticMethods() => calls.map((call) => call.method).toList();

  test('四类音效都能合成合法的 WAV 数据', () {
    for (final sound in GameSound.values) {
      final clip = SoundService.clipOf(sound);
      expect(clip.length, greaterThan(44));
      expect(String.fromCharCodes(clip.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(clip.sublist(8, 12)), 'WAVE');
      final header = ByteData.sublistView(clip);
      expect(header.getUint16(20, Endian.little), 1);
      expect(header.getUint16(22, Endian.little), 1);
      expect(header.getUint32(24, Endian.little), checkersSampleRate);
    }
    // 连跳比单步更长，终局提示音最长。
    expect(
      SoundService.clipOf(GameSound.jump).length,
      greaterThan(SoundService.clipOf(GameSound.step).length),
    );
    expect(
      SoundService.clipOf(GameSound.win).length,
      greaterThan(SoundService.clipOf(GameSound.jump).length),
    );
  });

  test('选子只发出轻触感，不播放提示音', () async {
    SoundService.play(GameSound.select);
    await Future<void>.delayed(Duration.zero);
    expect(played, [GameSound.select]);
    expect(hapticTypes(), contains('HapticFeedbackType.selectionClick'));
  });

  test('落子与连跳分别使用更强的震动', () async {
    SoundService.play(GameSound.step);
    SoundService.play(GameSound.jump);
    SoundService.play(GameSound.win);
    await Future<void>.delayed(Duration.zero);

    expect(played, [GameSound.step, GameSound.jump, GameSound.win]);
    expect(hapticTypes(), contains('HapticFeedbackType.lightImpact'));
    expect(hapticTypes(), contains('HapticFeedbackType.mediumImpact'));
    expect(hapticMethods(), contains('HapticFeedback.vibrate'));
  });

  test('关闭音效后不再播放，但震动仍可单独控制', () async {
    SoundService.configure(sound: false, haptics: false);
    SoundService.play(GameSound.step);
    await Future<void>.delayed(Duration.zero);
    expect(played, isEmpty);
    expect(calls, isEmpty);
  });
}
