import 'package:flutter/material.dart';

import '../models/txn.dart';
import '../state/ledger_store.dart';
import '../widgets/charts.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.store, required this.onAdd});

  final LedgerStore store;
  final VoidCallback onAdd;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _tab = 0;
  DateTime _day = DateTime.now();
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          color: theme.scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('每日'), icon: Icon(Icons.ac_unit)),
                ButtonSegment(value: 1, label: Text('每月'), icon: Icon(Icons.calendar_month)),
                ButtonSegment(value: 2, label: Text('每年'), icon: Icon(Icons.calendar_today)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
              showSelectedIcon: false,
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) {
              switch (_tab) {
                case 1:
                  return _MonthlyView(
                    store: widget.store,
                    month: _month,
                    onMonthChanged: (m) => setState(() => _month = m),
                  );
                case 2:
                  return _YearlyView(
                    store: widget.store,
                    year: _year,
                    onYearChanged: (y) => setState(() => _year = y),
                  );
                default:
                  return _DailyView(
                    store: widget.store,
                    day: _day,
                    onDayChanged: (d) => setState(() => _day = d),
                    onAdd: widget.onAdd,
                  );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _RangePickerBar extends StatelessWidget {
  const _RangePickerBar({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.isMaxReached,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final bool isMaxReached;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.tune, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 17)),
        ),
        IconButton(
          onPressed: isMaxReached ? null : onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _DailyView extends StatelessWidget {
  const _DailyView({
    required this.store,
    required this.day,
    required this.onDayChanged,
    required this.onAdd,
  });

  final LedgerStore store;
  final DateTime day;
  final ValueChanged<DateTime> onDayChanged;
  final VoidCallback onAdd;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) onDayChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final today = dayKey(DateTime.now());
    final summary = store.summaryOfDay(day);
    final txns = store.txnsOfDay(day);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      children: [
        _RangePickerBar(
          label: '${formatDay(day)} ${weekdayLabel(day)}',
          onPrev: () => onDayChanged(day.subtract(const Duration(days: 1))),
          onNext: () {
            final next = day.add(const Duration(days: 1));
            if (dayKey(next).compareTo(today) <= 0) onDayChanged(next);
          },
          onPick: () => _pick(context),
          isMaxReached: dayKey(day).compareTo(today) >= 0,
        ),
        const SizedBox(height: 8),
        SummaryCards(summary: summary, subtitle: formatDay(day)),
        const SizedBox(height: 12),
        CategoryPieCard(title: '当日支出构成', slices: summary.expenseByCategory),
        const SizedBox(height: 12),
        if (summary.incomeByCategory.isNotEmpty) ...[
          CategoryPieCard(title: '当日收入构成', slices: summary.incomeByCategory),
          const SizedBox(height: 12),
        ],
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当日流水', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (txns.isEmpty)
                  TextButton(
                    onPressed: onAdd,
                    child: const Text('今天还没有记账，点我去记一笔'),
                  )
                else
                  for (final t in txns) _TxnRow(txn: t),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlyView extends StatelessWidget {
  const _MonthlyView({
    required this.store,
    required this.month,
    required this.onMonthChanged,
  });

  final LedgerStore store;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      onMonthChanged(DateTime(picked.year, picked.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final summary = store.summaryOfMonth(month.year, month.month);
    final trend = store.dailyTrend(month.year, month.month);
    final busiest = trend.fold<TrendPoint?>(
      null,
      (best, p) => best == null || p.expense > best.expense ? p : best,
    );
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      children: [
        _RangePickerBar(
          label: formatMonth(month),
          onPrev: () =>
              onMonthChanged(DateTime(month.year, month.month - 1)),
          onNext: () =>
              onMonthChanged(DateTime(month.year, month.month + 1)),
          onPick: () => _pick(context),
          isMaxReached: !month.isBefore(nowMonth),
        ),
        const SizedBox(height: 8),
        SummaryCards(
          summary: summary,
          subtitle:
              '日均支出 ${formatMoney(summary.expense / daysInMonth)}',
        ),
        const SizedBox(height: 12),
        TrendBarCard(
          title: '每日收支趋势',
          points: trend,
          unitLabel: '日',
        ),
        const SizedBox(height: 8),
        const LegendRow(),
        const SizedBox(height: 12),
        CategoryPieCard(title: '本月支出构成', slices: summary.expenseByCategory),
        const SizedBox(height: 12),
        if (summary.incomeByCategory.isNotEmpty) ...[
          CategoryPieCard(title: '本月收入构成', slices: summary.incomeByCategory),
          const SizedBox(height: 12),
        ],
        if (busiest != null && busiest.expense > 0)
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.local_fire_department),
              title: const Text('花得最多的一天'),
              subtitle: Text('${month.month}月${busiest.label}日'),
              trailing: Text(
                formatMoney(busiest.expense),
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _YearlyView extends StatelessWidget {
  const _YearlyView({
    required this.store,
    required this.year,
    required this.onYearChanged,
  });

  final LedgerStore store;
  final int year;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    final years = store.years;
    final summary = store.summaryOfYear(year);
    final trend = store.monthlyTrend(year);
    final peak = trend.fold<TrendPoint?>(
      null,
      (best, p) => best == null || p.expense > best.expense ? p : best,
    );
    final thisYear = DateTime.now().year;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      children: [
        _RangePickerBar(
          label: '$year 年',
          onPrev: () => onYearChanged(year - 1),
          onNext: () => onYearChanged(year + 1),
          isMaxReached: year >= thisYear,
          onPick: () async {
            final picked = await showDialog<int>(
              context: context,
              builder: (context) => SimpleDialog(
                title: const Text('选择年份'),
                children: [
                  for (final y in years)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, y),
                      child: Text('$y 年'),
                    ),
                ],
              ),
            );
            if (picked != null) onYearChanged(picked);
          },
        ),
        const SizedBox(height: 8),
        SummaryCards(
          summary: summary,
          subtitle: '月均支出 ${formatMoney(summary.expense / 12)}',
        ),
        const SizedBox(height: 12),
        TrendBarCard(
          title: '每月收支趋势',
          points: trend,
          unitLabel: '月',
        ),
        const SizedBox(height: 8),
        const LegendRow(),
        const SizedBox(height: 12),
        CategoryPieCard(title: '全年支出构成', slices: summary.expenseByCategory),
        const SizedBox(height: 12),
        if (summary.incomeByCategory.isNotEmpty) ...[
          CategoryPieCard(title: '全年收入构成', slices: summary.incomeByCategory),
          const SizedBox(height: 12),
        ],
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Text(
                  '月度对比',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final p in trend)
                if (p.expense > 0)
                  _MonthBar(
                    label: '${p.label}月',
                    amount: p.expense,
                    maxAmount: peak?.expense ?? 1,
                  ),
              if (trend.every((p) => p.expense == 0))
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('这一年还没有支出记录'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.label,
    required this.amount,
    required this.maxAmount,
  });

  final String label;
  final double amount;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: maxAmount <= 0 ? 0 : amount / maxAmount,
                minHeight: 10,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              formatMoney(amount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final cat = txn.category;
    final isExpense = txn.type == TxnType.expense;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: cat.color.withValues(alpha: 0.18),
        child: Icon(cat.icon, size: 18, color: cat.color),
      ),
      title: Text(cat.label + (txn.note.isEmpty ? '' : ' · ${txn.note}')),
      subtitle: Text(
        DateTime.fromMillisecondsSinceEpoch(txn.createdAt)
            .toString()
            .substring(11, 16),
      ),
      trailing: Text(
        '${isExpense ? '-' : '+'}${formatMoney(txn.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isExpense ? const Color(0xFFE53935) : const Color(0xFF43A047),
        ),
      ),
    );
  }
}
