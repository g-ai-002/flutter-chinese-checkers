import 'package:flutter/foundation.dart';

/// 是否运行在桌面平台；Web 端一律按浏览器处理。
bool get isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);
