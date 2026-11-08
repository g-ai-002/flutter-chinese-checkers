import 'package:flutter/material.dart';

import '../../models/game_models.dart';
import '../../providers/settings_provider.dart';
import '../../theme/player_palette.dart';

Future<GameSetup?> showGameSetupSheet(
  BuildContext context, {
  required PlayMode mode,
  required SettingsProvider settings,
}) {
  return showModalBottomSheet<GameSetup>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => _SetupSheet(mode: mode, settings: settings),
  );
}

class _SetupSheet extends StatefulWidget {
  const _SetupSheet({required this.mode, required this.settings});

  final PlayMode mode;
  final SettingsProvider settings;

  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  late PlayerCount _count;
  late Difficulty _difficulty;
  late int _seat;

  @override
  void initState() {
    super.initState();
    _count = widget.settings.playerCount;
    _difficulty = widget.settings.difficulty;
    _seat = widget.settings.humanSeat.clamp(0, _count.count - 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAi = widget.mode == PlayMode.vsAi;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.mode.label, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                isAi ? '你与电脑轮流落子，其余座位由电脑接管。' : '同一台设备上轮流操作，适合面对面手谈。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _ChoiceGroup(
                label: '玩家人数',
                children: [
                  for (final value in PlayerCount.values)
                    ChoiceChip(
                      label: Text(value.label),
                      selected: _count == value,
                      onSelected: (_) => setState(() {
                        _count = value;
                        if (_seat >= value.count) _seat = 0;
                      }),
                    ),
                ],
              ),
              if (isAi) ...[
                const SizedBox(height: 20),
                _ChoiceGroup(
                  label: '我的座位',
                  children: [
                    for (var seat = 0; seat < _count.count; seat++)
                      ChoiceChip(
                        avatar: CircleAvatar(backgroundColor: playerStyleOf(seat).main, radius: 6),
                        label: Text('座位 ${seat + 1}'),
                        selected: _seat == seat,
                        onSelected: (_) => setState(() => _seat = seat),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _ChoiceGroup(
                  label: '电脑难度',
                  children: [
                    for (final value in Difficulty.values)
                      ChoiceChip(
                        label: Text(value.label),
                        selected: _difficulty == value,
                        onSelected: (_) => setState(() => _difficulty = value),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _difficulty.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await widget.settings.setPlayerCount(_count);
                    await widget.settings.setDifficulty(_difficulty);
                    if (isAi) await widget.settings.setHumanSeat(_seat);
                    if (!context.mounted) return;
                    Navigator.of(context).pop(
                      GameSetup(
                        mode: widget.mode,
                        playerCount: _count,
                        difficulty: _difficulty,
                        humanSeat: isAi ? _seat : 0,
                      ),
                    );
                  },
                  child: const Text('开始对局'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceGroup extends StatelessWidget {
  const _ChoiceGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}
