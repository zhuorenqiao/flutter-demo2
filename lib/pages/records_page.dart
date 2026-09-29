import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/txn.dart';
import '../state/ledger_store.dart';
import '../utils/run_guarded.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, required this.store});

  final LedgerStore store;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  /// 距底部多少像素就预取下一页。
  static const _preloadExtent = 200.0;

  final ScrollController _scroll = ScrollController();

  LedgerStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - _preloadExtent) {
      store.loadMore();
    }
  }

  Future<void> _confirmDelete(BuildContext context, Txn txn) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这笔记录？'),
        content: Text('${txn.category.label}  ${formatMoney(txn.amount)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runGuarded(context, () => store.remove(txn), failure: '删除失败');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (store.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (store.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('读取服务器账单失败：${store.error}'),
            ),
          );
        }
        final groups = store.dayGroups;
        if (groups.isEmpty) return _buildEmpty(context);

        return ListView.builder(
          controller: _scroll,
          // 数据不足一屏时也允许下拉，否则永远触发不了滚动加载
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: groups.length + 1,
          itemBuilder: (context, i) {
            if (i == groups.length) return _footer();
            return _daySection(context, groups[i]);
          },
        );
      },
    );
  }

  Widget _daySection(BuildContext context, DayGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatDay(group.day)} ${weekdayLabel(group.day)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '支出 ${formatMoney(group.expense)}   收入 ${formatMoney(group.income)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (final t in group.txns)
                Dismissible(
                  key: ValueKey('${t.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: kExpense,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    await _confirmDelete(context, t);
                    return false; // 由对话框决定是否删除
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: t.category.color.withValues(alpha: 0.18),
                      child: Icon(t.category.icon,
                          size: 18, color: t.category.color),
                    ),
                    title: Text(
                      t.category.label +
                          (t.note.isEmpty ? '' : ' · ${t.note}'),
                    ),
                    subtitle: Text(
                      DateTime.fromMillisecondsSinceEpoch(t.createdAt)
                          .toString()
                          .substring(5, 16)
                          .replaceFirst('-', '/'),
                    ),
                    trailing: Text(
                      '${t.type == TxnType.expense ? '-' : '+'}${formatMoney(t.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: t.type == TxnType.expense ? kExpense : kIncome,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    if (store.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (store.moreError != null) {
      return Center(
        child: TextButton(
          onPressed: () => store.loadMore(),
          child: Text('加载失败，点击重试：${store.moreError}'),
        ),
      );
    }
    if (!store.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('已经到底了', style: TextStyle(fontSize: 12))),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('还没有任何账单'),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => runGuarded(context, store.seedDemoData),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('载入示例数据，体验图表'),
            ),
          ],
        ),
      ),
    );
  }
}
