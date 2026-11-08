import 'dart:isolate';
import 'dart:typed_data';

import 'tone_synth.dart';

/// 在后台 isolate 合成 16 秒背景音乐，避免启动时占用 UI 线程。
Future<Uint8List> synthesizeMusicInBackground() => Isolate.run(synthesizeMusicWav);
