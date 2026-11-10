import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../services/log_service.dart';
import 'constants.dart';

/// 桌面窗口初始化：仅 Windows 生效，设定初始尺寸并居中显示。
Future<void> setupDesktopWindow() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
  try {
    final window = WindowManager.instance.getCurrent();
    if (window == null) {
      LogService.warning('窗口管理器初始化失败: 未取到当前窗口');
      return;
    }
    window.title = AppConstants.appName;
    window.titleBarStyle = TitleBarStyle.normal;
    window.isVisibleInTaskbar = true;
    window.minimumSize = const Size(420, 640).toNative();
    window.setSize(const Size(1180, 860).toNative(), false);
    window.center();
    window.show();
    window.focus();
  } catch (e) {
    LogService.warning('窗口管理器初始化失败: $e');
  }
}
