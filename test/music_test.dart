import 'dart:typed_data';

import 'package:chinese_checkers/services/music_service.dart';
import 'package:chinese_checkers/services/music_synth.dart';
import 'package:chinese_checkers/services/tone_synth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(MusicService.reset);

  test('背景音乐是 16 秒的循环 WAV', () {
    final clip = synthesizeMusicWav();
    final header = ByteData.sublistView(clip);
    expect(String.fromCharCodes(clip.sublist(0, 4)), 'RIFF');
    expect(header.getUint32(24, Endian.little), kMusicSampleRate);
    expect(
      header.getUint32(40, Endian.little),
      kMusicLoopSeconds * kMusicSampleRate * 2,
    );
    expect(clip.length, 44 + kMusicLoopSeconds * kMusicSampleRate * 2);
  });

  test('后台合成与直接合成的音乐一致', () async {
    final background = await synthesizeMusicInBackground();
    expect(background, synthesizeMusicWav());
  });

  test('开关背景音乐只触发一次状态切换', () async {
    final states = <bool>[];
    MusicService.sink = states.add;
    await MusicService.setEnabled(false);
    await MusicService.setEnabled(true);
    expect(states, [false, true]);
    expect(MusicService.enabled, isTrue);
  });

  test('未启用时不会尝试播放', () async {
    var called = false;
    MusicService.sink = (_) => called = true;
    MusicService.enabled = false;
    await MusicService.start();
    expect(called, isFalse);
  });
}
