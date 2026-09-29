import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../app_theme.dart';
import '../state/ledger_store.dart';
import '../state/theme_mode_controller.dart';
import '../utils/run_guarded.dart';
import 'add_txn_page.dart';
import 'analytics_page.dart';
import 'profile_page.dart';
import 'records_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.store,
    required this.session,
    required this.theme,
  });

  final LedgerStore store;
  final AuthSession session;
  final ThemeModeController theme;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  Future<void> _openAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTxnPage(store: widget.store)),
    );
  }

  void _onMenu(String value) {
    switch (value) {
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfilePage(session: widget.session)),
        );
      case 'seed':
        runGuarded(context, widget.store.seedDemoData);
      case 'clear':
        _clearAll();
      case 'theme':
        _pickThemeMode();
      case 'signout':
        widget.session.signOut();
    }
  }

  static const _themeChoices = <(ThemeMode, String, IconData)>[
    (ThemeMode.system, '跟随系统', Icons.brightness_auto),
    (ThemeMode.light, '浅色', Icons.light_mode),
    (ThemeMode.dark, '深色', Icons.dark_mode),
  ];

  Future<void> _pickThemeMode() async {
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('切换主题'),
        children: [
          for (final (mode, label, icon) in _themeChoices)
            ListTile(
              dense: true,
              leading: Icon(icon),
              title: Text(label),
              trailing: widget.theme.mode == mode
                  ? const Icon(Icons.check, color: kPrimary)
                  : null,
              onTap: () => Navigator.pop(context, mode),
            ),
        ],
      ),
    );
    if (picked != null) await widget.theme.setMode(picked);
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有账单？'),
        content: const Text('服务器上的全部账单记录会被删除，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runGuarded(context, widget.store.clearAll);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? '我的账本' : '收支报表'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenu,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.person_outline),
                  title: Text('个人中心'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'seed',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.auto_awesome),
                  title: Text('载入示例数据'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.delete_sweep),
                  title: Text('清空账单'),
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.palette_outlined),
                  title: Text('切换主题（${widget.theme.label}）'),
                ),
              ),
              PopupMenuItem(
                value: 'signout',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.logout),
                  title: Text('退出登录（${widget.session.displayName}）'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          RecordsPage(store: widget.store),
          AnalyticsPage(store: widget.store, onAdd: _openAdd),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: '流水',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart),
            label: '报表',
          ),
        ],
      ),
    );
  }
}
