import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'auth/auth_session.dart';
import 'data/remote_ledger_repository.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'state/ledger_store.dart';
import 'state/theme_mode_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    LedgerApp(
      session: await AuthSession.restore(),
      theme: await ThemeModeController.restore(),
    ),
  );
}

class LedgerApp extends StatefulWidget {
  const LedgerApp({super.key, required this.session, this.theme, this.storeFactory});

  final AuthSession session;

  /// 主题模式控制器；不传则跟随系统且不持久化（测试用）。
  final ThemeModeController? theme;

  /// 测试可注入本地仓库；默认按登录态创建后端仓库。
  final LedgerStore Function(AuthSession session)? storeFactory;

  @override
  State<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<LedgerApp> {
  late final ThemeModeController _theme = widget.theme ?? ThemeModeController.defaults();

  LedgerStore? _store;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
    _theme.addListener(_onThemeChanged);
    if (widget.session.isSignedIn) _openStore();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _theme.removeListener(_onThemeChanged);
    _store?.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onSessionChanged() {
    if (widget.session.isSignedIn) {
      if (_store == null) _openStore();
    } else {
      _store?.dispose();
      _store = null;
    }
    if (mounted) setState(() {});
  }

  void _openStore() {
    _store = (widget.storeFactory ?? _remoteStore)(widget.session)..load();
  }

  static LedgerStore _remoteStore(AuthSession session) =>
      LedgerStore(RemoteLedgerRepository(session.api));

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return MaterialApp(
      title: '记账本',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: _theme.mode,
      home: store == null
          ? LoginPage(session: widget.session)
          : HomePage(store: store, session: widget.session, theme: _theme),
    );
  }
}
