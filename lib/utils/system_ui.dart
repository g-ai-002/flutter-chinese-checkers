import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 系统栏（状态栏与导航栏）样式：透明底色，图标深浅由背景亮度决定。
///
/// Android 15 起系统强制边到边绘制，`statusBarColor` 已不再生效，状态栏图标
/// 能否看清只取决于图标亮度与页面顶部的底色对比，因此这里按背景色推导。
SystemUiOverlayStyle systemOverlayStyleFor(Color background) {
  final dark = background.computeLuminance() < 0.5;
  final iconBrightness = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    // iOS 的语义与 Android 相反：状态栏底色深才配浅色图标。
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}

/// 按当前主题的页面底色设置系统栏样式，随深浅色模式切换。
///
/// 放在 `MaterialApp.builder` 里包住整个应用；页面若自带与主题不同的底色
/// （如深色对局场地），可用自己的 `AnnotatedRegion` 覆盖这里的默认值。
class SystemUiOverlay extends StatelessWidget {
  const SystemUiOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyleFor(Theme.of(context).scaffoldBackgroundColor),
      child: child,
    );
  }
}
