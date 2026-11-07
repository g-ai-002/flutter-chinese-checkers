import 'dart:typed_data';

import 'tone_synth.dart';

/// Web 没有 isolate，直接合成；音频初始化已延后到首帧之后，不会拖慢启动。
Future<Uint8List> synthesizeMusicInBackground() async => synthesizeMusicWav();
