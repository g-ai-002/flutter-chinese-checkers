import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinese_checkers/utils/system_ui.dart';

void main() {
  test('浅色底色配深色状态栏与导航栏图标', () {
    final style = systemOverlayStyleFor(const Color(0xFFF6F2E8));
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.statusBarBrightness, Brightness.light);
    expect(style.statusBarColor, Colors.transparent);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    expect(style.systemNavigationBarColor, Colors.transparent);
  });

  test('深色底色配浅色状态栏与导航栏图标', () {
    final style = systemOverlayStyleFor(const Color(0xFF141715));
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
  });
}
