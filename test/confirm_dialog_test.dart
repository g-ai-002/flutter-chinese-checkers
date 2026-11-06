import 'package:chinese_checkers/pages/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('确认浮层展示标题、说明与自定义按钮', (tester) async {
    bool? result;
    await tester.pumpWidget(_Host(onResult: (value) => result = value));

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('删除这份棋谱？'), findsOneWidget);
    expect(find.text('删除后无法恢复。'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '删除'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.text('删除这份棋谱？'), findsNothing);
  });

  testWidgets('确认后返回 true 并关闭浮层', (tester) async {
    bool? result;
    await tester.pumpWidget(_Host(onResult: (value) => result = value));

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.text('删除这份棋谱？'), findsNothing);
  });

  testWidgets('点击浮层外空白按取消处理', (tester) async {
    bool? result;
    await tester.pumpWidget(_Host(onResult: (value) => result = value));

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}

class _Host extends StatelessWidget {
  const _Host({required this.onResult});

  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await showConfirmDialog(
                  context,
                  title: '删除这份棋谱？',
                  message: '删除后无法恢复。',
                  confirmLabel: '删除',
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
  }
}
