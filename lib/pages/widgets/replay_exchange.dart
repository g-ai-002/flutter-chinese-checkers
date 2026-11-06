import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/replay_archive.dart';
import '../../services/file_system_service.dart';
import '../../utils/formatters.dart';

/// 导出棋谱：展示分享码，可复制或另存为文本文件。
Future<void> showReplayExportDialog(
  BuildContext context,
  ReplayArchive archive,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _ReplayExportDialog(archive: archive),
  );
}

/// 导入棋谱：粘贴分享码，解析通过后返回棋谱，取消或失败返回 null。
Future<ReplayArchive?> showReplayImportDialog(BuildContext context) {
  return showDialog<ReplayArchive>(
    context: context,
    builder: (dialogContext) => const _ReplayImportDialog(),
  );
}

class _ReplayExportDialog extends StatefulWidget {
  const _ReplayExportDialog({required this.archive});

  final ReplayArchive archive;

  @override
  State<_ReplayExportDialog> createState() => _ReplayExportDialogState();
}

class _ReplayExportDialogState extends State<_ReplayExportDialog> {
  /// 分享码内容较长，只在打开浮层时编码一次，复制与保存复用同一份。
  late final String _shareCode = widget.archive.encode();
  String? _savedPath;
  bool _saving = false;

  Future<void> _saveToFile() async {
    setState(() => _saving = true);
    final path = await FileSystemService.instance.saveExport(
      replayFileName(widget.archive.savedAt),
      '$_shareCode\n',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedPath = path;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _shareCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('分享码已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('导出棋谱'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '把分享码发给朋友，或在棋谱库里粘贴导入，即可回看同一局。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _shareCode,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            if (_savedPath != null) ...[
              const SizedBox(height: 10),
              Text(
                '已保存到本机：$_savedPath',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!kIsWeb)
          TextButton.icon(
            onPressed: _saving ? null : _saveToFile,
            icon: const Icon(Icons.save_alt, size: 18),
            label: Text(_saveButtonLabel),
          ),
        TextButton.icon(
          onPressed: _copy,
          icon: const Icon(Icons.copy_all_outlined, size: 18),
          label: const Text('复制'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }

  String get _saveButtonLabel {
    if (_saving) return '保存中';
    return _savedPath == null ? '保存文件' : '再次保存';
  }
}

class _ReplayImportDialog extends StatefulWidget {
  const _ReplayImportDialog();

  @override
  State<_ReplayImportDialog> createState() => _ReplayImportDialogState();
}

class _ReplayImportDialogState extends State<_ReplayImportDialog> {
  final TextEditingController _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      setState(() => _error = '剪贴板里没有可导入的文本');
      return;
    }
    _input.text = text;
    setState(() => _error = null);
  }

  void _submit() {
    final archive = ReplayArchive.decode(_input.text);
    if (archive == null) {
      setState(() => _error = '分享码无法识别，请确认完整复制后再试');
      return;
    }
    Navigator.of(context).pop(archive);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('导入棋谱'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '粘贴 `TIAOQI1:` 开头的分享码，导入后可直接复盘。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _input,
              minLines: 5,
              maxLines: 9,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: '在此粘贴分享码',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _paste,
          icon: const Icon(Icons.content_paste, size: 18),
          label: const Text('粘贴'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('导入')),
      ],
    );
  }
}
