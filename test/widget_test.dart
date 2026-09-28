import 'package:flutter/material.dart';
import 'package:flutter_demo2/data/ledger_repository.dart';
import 'package:flutter_demo2/main.dart';
import 'package:flutter_demo2/state/ledger_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('首页渲染出底部导航与记账入口', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      LedgerApp(LedgerStore(SharedPreferencesRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '我的账本'), findsOne);
    expect(find.text('流水'), findsOne);
    expect(find.text('报表'), findsOne);
    expect(find.text('记一笔'), findsOne);
  });
}
