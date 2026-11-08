import 'package:flutter/material.dart';

/// 统一的面板容器：标题 + 可选右侧操作 + 内容。
///
/// 统计、设置与对局页的卡片共用同一套圆角、描边与内边距，
/// 需要在卡片内使用 [ListTile] 等带水波纹的组件时也能正常显示。
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(14),
    this.headerGap = 10,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;
  final double headerGap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = title;
    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (heading != null) ...[
              Row(
                children: [
                  Expanded(child: Text(heading, style: theme.textTheme.titleSmall)),
                  ?trailing,
                ],
              ),
              SizedBox(height: headerGap),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
