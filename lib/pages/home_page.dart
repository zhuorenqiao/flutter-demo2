import 'package:flutter/material.dart';

import '../state/ledger_store.dart';
import 'add_txn_page.dart';
import 'analytics_page.dart';
import 'records_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});

  final LedgerStore store;

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

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有账单？'),
        content: const Text('本地数据库中的记录会被全部删除，此操作不可撤销。'),
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
    if (ok == true) await widget.store.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? '我的账本' : '收支报表'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'seed'
                ? widget.store.seedDemoData()
                : _clearAll(),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'seed',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.auto_awesome),
                  title: Text('载入示例数据'),
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.delete_sweep),
                  title: Text('清空账单'),
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
