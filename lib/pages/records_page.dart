import 'package:flutter/material.dart';

import '../models/txn.dart';
import '../state/ledger_store.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key, required this.store});

  final LedgerStore store;

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
    if (ok == true) await store.remove(txn);
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
              child: Text('读取本地数据库失败：${store.error}'),
            ),
          );
        }
        final groups = store.dayGroups;
        if (groups.isEmpty) return _buildEmpty(context);

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: groups.length,
          itemBuilder: (context, i) {
            final g = groups[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      Text(
                        '${formatDay(g.day)} ${weekdayLabel(g.day)}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      Text(
                        '支出 ${formatMoney(g.expense)}   收入 ${formatMoney(g.income)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      for (final t in g.txns)
                        Dismissible(
                          key: ValueKey('${t.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: const Color(0xFFE53935),
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
                                color: t.type == TxnType.expense
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF43A047),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
              onPressed: () => store.seedDemoData(),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('载入示例数据，体验图表'),
            ),
          ],
        ),
      ),
    );
  }
}
