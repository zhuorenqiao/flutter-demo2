import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/txn.dart';
import '../state/ledger_store.dart';

class AddTxnPage extends StatefulWidget {
  const AddTxnPage({super.key, required this.store});

  final LedgerStore store;

  @override
  State<AddTxnPage> createState() => _AddTxnPageState();
}

class _AddTxnPageState extends State<AddTxnPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TxnType _type = TxnType.expense;
  String _categoryKey = kExpenseCategories.first.key;
  DateTime _day = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _switchType(TxnType type) {
    setState(() {
      _type = type;
      _categoryKey = categoriesOf(type).first.key;
    });
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入大于 0 的金额')),
      );
      return;
    }
    setState(() => _saving = true);
    await widget.store.add(
      Txn(
        type: _type,
        categoryKey: _categoryKey,
        amount: double.parse(amount.toStringAsFixed(2)),
        day: dayKey(_day),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        note: _noteCtrl.text.trim(),
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已记录 ${_type.name == 'expense' ? '支出' : '收入'} ${formatMoney(amount)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cats = categoriesOf(_type);
    return Scaffold(
      appBar: AppBar(title: const Text('记一笔')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TxnType>(
            segments: const [
              ButtonSegment(
                value: TxnType.expense,
                label: Text('支出'),
                icon: Icon(Icons.arrow_upward),
              ),
              ButtonSegment(
                value: TxnType.income,
                label: Text('收入'),
                icon: Icon(Icons.arrow_downward),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => _switchType(s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                autofocus: true,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  prefixText: '¥ ',
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.black26),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('分类', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in cats)
                _CategoryChip(
                  category: c,
                  selected: c.key == _categoryKey,
                  onTap: () => setState(() => _categoryKey = c.key),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text('日期'),
                  trailing: Text(formatDay(_day)),
                  onTap: _pickDay,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.edit_note),
                      border: InputBorder.none,
                      hintText: '备注（可选）',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final TxnCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? category.color : Theme.of(context).colorScheme.outlineVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? category.color.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Icon(category.icon, color: selected ? category.color : null),
            const SizedBox(height: 4),
            Text(
              category.label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? category.color : null,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
