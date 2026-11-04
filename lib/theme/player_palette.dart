import 'package:flutter/material.dart';

/// 六位玩家的固定配色：两人局取红/蓝，三人局取红/蓝/绿，四种颜色足够区分。
class PlayerStyle {
  const PlayerStyle({
    required this.name,
    required this.main,
    required this.dark,
    required this.light,
    required this.ink,
  });

  final String name;
  final Color main;
  final Color dark;
  final Color light;
  final Color ink;
}

const List<PlayerStyle> kPlayerStyles = [
  PlayerStyle(
    name: '红方',
    main: Color(0xFFC94A3D),
    dark: Color(0xFF8C2A21),
    light: Color(0xFFF09186),
    ink: Color(0xFFFFF6F2),
  ),
  PlayerStyle(
    name: '蓝方',
    main: Color(0xFF3B6FA8),
    dark: Color(0xFF1F4368),
    light: Color(0xFF8FB8DE),
    ink: Color(0xFFF4F9FF),
  ),
  PlayerStyle(
    name: '绿方',
    main: Color(0xFF3E8C5F),
    dark: Color(0xFF1E5636),
    light: Color(0xFF92C9A9),
    ink: Color(0xFFF5FCF7),
  ),
  PlayerStyle(
    name: '黄方',
    main: Color(0xFFC6912C),
    dark: Color(0xFF7D5611),
    light: Color(0xFFEDCB82),
    ink: Color(0xFFFFFAEE),
  ),
  PlayerStyle(
    name: '紫方',
    main: Color(0xFF7B5CA6),
    dark: Color(0xFF472E6B),
    light: Color(0xFFC2ACDD),
    ink: Color(0xFFFAF6FF),
  ),
  PlayerStyle(
    name: '青方',
    main: Color(0xFF2E8B8B),
    dark: Color(0xFF145555),
    light: Color(0xFF8CCACA),
    ink: Color(0xFFF2FDFD),
  ),
];

PlayerStyle playerStyleOf(int seat) =>
    kPlayerStyles[seat % kPlayerStyles.length];
