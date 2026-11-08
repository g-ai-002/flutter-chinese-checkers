import 'package:flutter/foundation.dart';

/// 是否运行在桌面平台；Web 端一律按浏览器处理。
bool get isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// 是否运行在手机系统上；只有这里的方向锁定与横屏全屏才生效。
bool get isMobilePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
