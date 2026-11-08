import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/game_models.dart';
import '../providers/settings_provider.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/platform_info.dart';
import 'widgets/surface_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _Section(
              title: '外观',
              children: [
                _switch(settings.darkMode, settings.setDarkMode, '深色模式', '夜间对局更柔和'),
                const SizedBox(height: 10),
                Text('棋盘配色', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final boardTheme in kBoardThemes) ...[
                      Expanded(
                        child: _ThemeTile(
                          boardTheme: boardTheme,
                          selected: settings.boardTheme.id == boardTheme.id,
                          onTap: () => settings.setBoardTheme(boardTheme),
                        ),
                      ),
                      if (boardTheme != kBoardThemes.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Section(
              title: '声音与触感',
              children: [
                _switch(settings.soundEnabled, settings.setSoundEnabled, '走子音效', '单步、连跳与终局提示音'),
                _switch(settings.musicEnabled, settings.setMusicEnabled, '背景音乐', '运行时合成的五声音阶循环'),
                _switch(settings.hapticsEnabled, settings.setHapticsEnabled, '震动反馈', '移动端选子与落子时轻震'),
              ],
            ),
            const SizedBox(height: 14),
            _Section(
              title: '对局',
              children: [
                _switch(settings.showHints, settings.setShowHints, '显示可走位置', '选中棋子后标出所有落点'),
                _choice(
                  context,
                  '默认玩家人数',
                  settings.playerCount.label,
                  PlayerCount.values,
                  (count) => count.label,
                  settings.setPlayerCount,
                ),
                _choice(
                  context,
                  '逻辑更新速率',
                  '${settings.logicRate.label} · ${settings.logicRate.description}',
                  LogicRate.values,
                  (rate) => '${rate.label} · ${rate.description}',
                  settings.setLogicRate,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Section(
              title: '日志',
              children: [
                Text(
                  isDesktopPlatform ? '日志按天写入用户目录，遇到问题可把日志文件提供给开发者。' : '日志按天写入应用目录，遇到问题可查看最近记录。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showLogs(context),
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('查看最近日志'),
                      ),
                    ),
                    if (isDesktopPlatform) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openLogFolder(context),
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('打开日志目录'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  AppConstants.appDirName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Center(
              child: Text(
                '${AppConstants.appName} v${AppConstants.version} · 本地运行，无需联网',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(bool value, ValueChanged<bool> onChanged, String title, String subtitle) =>
      SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        value: value,
        onChanged: onChanged,
        title: Text(title),
        subtitle: Text(subtitle),
      );

  Widget _choice<T>(
    BuildContext context,
    String title,
    String subtitle,
    List<T> values,
    String Function(T value) label,
    Future<void> Function(T value) onPicked,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
    onTap: () => _pickOption(context, title, values, label, onPicked),
  );

  Future<void> _pickOption<T>(
    BuildContext context,
    String title,
    List<T> values,
    String Function(T value) label,
    Future<void> Function(T value) onPicked,
  ) async {
    final value = await showDialog<T>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(title),
        children: [
          for (final item in values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(item),
              child: Text(label(item)),
            ),
        ],
      ),
    );
    if (value != null) await onPicked(value);
  }

  Future<void> _showLogs(BuildContext context) async {
    final logs = LogService.getRecentLogs(300);
    final path = LogService.logFilePath.isNotEmpty
        ? LogService.logFilePath
        : await FileSystemService.instance.getLogRootPath();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('最近日志'),
          scrollable: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (path.isNotEmpty)
                Text(
                  path,
                  maxLines: 2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 10),
              SelectableText(
                logs.isEmpty ? '暂无日志' : logs.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: logs.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: logs.join('\n')));
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext)
                            .showSnackBar(const SnackBar(content: Text('日志已复制')));
                      }
                    },
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              label: const Text('复制'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openLogFolder(BuildContext context) async {
    final path = await FileSystemService.instance.getLogRootPath();
    final opened = await FileSystemService.instance.openDirectory(path);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('无法打开目录：$path')));
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      title: title,
      headerGap: 8,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.boardTheme, required this.selected, required this.onTap});

  final BoardTheme boardTheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [boardTheme.plateTop, boardTheme.plateBottom],
              ),
              border: Border.all(
                color: selected ? theme.colorScheme.primary : Colors.transparent,
                width: 2.4,
              ),
            ),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: boardTheme.holeFill,
                border: Border.all(color: boardTheme.holeEdge, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            boardTheme.name,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
