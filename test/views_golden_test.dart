import 'package:flutter/material.dart';
import 'package:flutter_demo2/app_theme.dart';
import 'package:flutter_demo2/auth/auth_session.dart';
import 'package:flutter_demo2/data/ledger_repository.dart';
import 'package:flutter_demo2/models/txn.dart' show formatDay;
import 'package:flutter_demo2/pages/add_txn_page.dart';
import 'package:flutter_demo2/pages/analytics_page.dart';
import 'package:flutter_demo2/pages/home_page.dart';
import 'package:flutter_demo2/pages/login_page.dart';
import 'package:flutter_demo2/pages/records_page.dart';
import 'package:flutter_demo2/state/ledger_store.dart';
import 'package:flutter_demo2/state/theme_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(body: child),
);

Future<LedgerStore> _seededStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = LedgerStore(SharedPreferencesRepository());
  await store.load();
  await store.seedDemoData();
  return store;
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2160);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('流水页按天分组渲染', (tester) async {
    _usePhoneViewport(tester);
    final store = await _seededStore();

    await tester.pumpWidget(_wrap(RecordsPage(store: store)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RecordsPage),
      matchesGoldenFile('goldens/records.png'),
    );
    expect(tester.takeException(), isNull);
  });

  for (final (label, index) in const [('每日', 0), ('每月', 1), ('每年', 2)]) {
    testWidgets('报表 $label 视图渲染', (tester) async {
      _usePhoneViewport(tester);
      final store = await _seededStore();

      await tester.pumpWidget(_wrap(AnalyticsPage(store: store, onAdd: () {})));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AnalyticsPage),
        matchesGoldenFile('goldens/analytics_$index.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in const [320.0, 360.0, 415.0]) {
    testWidgets('$width 逻辑宽度下切换按钮图标与文字都完整', (tester) async {
      tester.view.physicalSize = Size(width * 2, 800 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final store = await _seededStore();

      await tester.pumpWidget(
        _wrap(AnalyticsPage(store: store, onAdd: () {})),
      );
      await tester.pumpAndSettle();

      for (final label in const ['每日', '每月', '每年']) {
        // Ahem 字体下每个字符 13px，被裁切时矩形宽度会小于两个字
        final rect = tester.getRect(find.text(label));
        expect(rect.width, greaterThanOrEqualTo(26), reason: '$label 被裁切');
        expect(rect.height, lessThan(20), reason: '$label 被折行');
      }
      expect(find.byIcon(Icons.ac_unit), findsOne);
      expect(tester.takeException(), isNull);

      if (width == 320.0) {
        await expectLater(
          find.byType(AnalyticsPage),
          matchesGoldenFile('goldens/analytics_narrow.png'),
        );
      }
    });
  }

  testWidgets('首页整体配色（标题栏 / 悬浮按钮 / 底部导航）', (tester) async {
    _usePhoneViewport(tester);
    final store = await _seededStore();
    SharedPreferences.setMockInitialValues({});
    final session = await AuthSession.restore();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomePage(store: store, session: session, theme: ThemeModeController.defaults()),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(HomePage), matchesGoldenFile('goldens/home.png'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('深色主题首页渲染', (tester) async {
    _usePhoneViewport(tester);
    final store = await _seededStore();
    SharedPreferences.setMockInitialValues({});
    final session = await AuthSession.restore();
    final theme = ThemeModeController.defaults();
    await theme.setMode(ThemeMode.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        darkTheme: buildDarkAppTheme(),
        themeMode: theme.mode,
        home: HomePage(store: store, session: session, theme: theme),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(HomePage), matchesGoldenFile('goldens/home_dark.png'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('登录页配色', (tester) async {
    _usePhoneViewport(tester);
    SharedPreferences.setMockInitialValues({});
    final session = await AuthSession.restore();

    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: LoginPage(session: session)),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(LoginPage), matchesGoldenFile('goldens/login.png'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('日期选择器只允许今天及以前', (tester) async {
    _usePhoneViewport(tester);
    SharedPreferences.setMockInitialValues({});
    final store = LedgerStore(SharedPreferencesRepository());
    await store.load();

    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: AddTxnPage(store: store)),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final inMonthDay = now.subtract(const Duration(days: 3));

    // 尝试选后一天：确认后仍停留在今天
    await tester.tap(find.text('日期'));
    await tester.pumpAndSettle();
    final tomorrowCell = find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text('${tomorrow.day}'),
    );
    if (tomorrow.month == now.month && tomorrowCell.evaluate().isNotEmpty) {
      await tester.tap(tomorrowCell, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(formatDay(now)), findsOne);

    // 过去的日期可以正常选择
    await tester.tap(find.text('日期'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('${inMonthDay.day}'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(formatDay(inMonthDay)), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('记一笔页可保存账单', (tester) async {
    _usePhoneViewport(tester);
    SharedPreferences.setMockInitialValues({});
    final store = LedgerStore(SharedPreferencesRepository());
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AddTxnPage(store: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '88.50');
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await expectLater(
      find.byType(AddTxnPage),
      matchesGoldenFile('goldens/add_txn.png'),
    );

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(store.txns, hasLength(1));
    expect(store.txns.first.amount, 88.5);
    expect((await store.summaryOfDay(DateTime.now())).expense, 88.5);

    // 重新打开一次，确认已落库
    final reopened = LedgerStore(SharedPreferencesRepository());
    await reopened.load();
    expect(reopened.txns.single.categoryKey, 'food');
  });
}
