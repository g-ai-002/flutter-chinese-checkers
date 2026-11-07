/// 背景音乐合成入口：IO 平台放到后台 isolate，Web 平台直接在当前线程执行。
library;

export 'music_synth_io.dart'
    if (dart.library.js_interop) 'music_synth_web.dart';
