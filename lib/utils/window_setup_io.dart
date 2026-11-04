import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../services/log_service.dart';
import 'constants.dart';

/// 桌面窗口初始化：仅 Windows 生效，设定初始尺寸并居中显示。
Future<void> setupDesktopWindow() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
  try {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1180, 860),
      minimumSize: Size(420, 640),
      center: true,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: AppConstants.appName,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e) {
    LogService.warning('窗口管理器初始化失败: $e');
  }
}
