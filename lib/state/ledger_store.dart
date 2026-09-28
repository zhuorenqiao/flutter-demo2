import 'package:flutter/foundation.dart';

import '../data/ledger_repository.dart';
import '../models/txn.dart';

class CategorySlice {
  const CategorySlice(this.category, this.amount);

  final TxnCategory category;
  final double amount;
}

class Summary {
  const Summary({
    required this.expense,
    required this.income,
    required this.expenseByCategory,
    required this.incomeByCategory,
    required this.count,
  });

  final double expense;
  final double income;
  final List<CategorySlice> expenseByCategory;
  final List<CategorySlice> incomeByCategory;
  final int count;

  double get balance => income - expense;
}

class TrendPoint {
  const TrendPoint(this.label, this.expense, this.income);

  final String label;
  final double expense;
  final double income;
}

class DayGroup {
  const DayGroup(this.day, this.txns, this.expense, this.income);

  final DateTime day;
  final List<Txn> txns;
  final double expense;
  final double income;
}

/// 内存中持有一份账本，负责读写数据库并派生各类统计口径。
class LedgerStore extends ChangeNotifier {
  LedgerStore(this._repo);

  final LedgerRepository _repo;

  List<Txn> _txns = const [];
  bool _loading = true;
  Object? _error;

  List<Txn> get txns => _txns;
  bool get loading => _loading;
  Object? get error => _error;
  bool get isEmpty => _txns.isEmpty;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _txns = await _repo.loadAll();
    } catch (e) {
      _error = e;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> add(Txn txn) async {
    final saved = await _repo.insert(txn);
    _txns = [saved, ..._txns]..sort(_byDayDesc);
    notifyListeners();
  }

  Future<void> remove(Txn txn) async {
    final id = txn.id;
    if (id == null) return;
    await _repo.delete(id);
    _txns = _txns.where((t) => t.id != id).toList();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _repo.deleteAll();
    _txns = const [];
    notifyListeners();
  }

  Future<void> seedDemoData() async {
    await _repo.insertMany(_demoTxns());
    await load();
  }

  static int _byDayDesc(Txn a, Txn b) {
    final byDay = b.day.compareTo(a.day);
    return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
  }

  // ---------- 派生统计 ----------

  static Summary summarize(Iterable<Txn> txns) {
    var expense = 0.0, income = 0.0;
    final exp = <String, double>{};
    final inc = <String, double>{};
    for (final t in txns) {
      if (t.type == TxnType.expense) {
        expense += t.amount;
        exp[t.categoryKey] = (exp[t.categoryKey] ?? 0) + t.amount;
      } else {
        income += t.amount;
        inc[t.categoryKey] = (inc[t.categoryKey] ?? 0) + t.amount;
      }
    }
    List<CategorySlice> slices(Map<String, double> m) {
      final list = m.entries.map((e) => CategorySlice(categoryOf(e.key), e.value)).toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
      return list;
    }

    return Summary(
      expense: expense,
      income: income,
      expenseByCategory: slices(exp),
      incomeByCategory: slices(inc),
      count: txns.length,
    );
  }

  List<Txn> txnsOfDay(DateTime day) {
    final key = dayKey(day);
    return _txns.where((t) => t.day == key).toList();
  }

  Summary summaryOfDay(DateTime day) => summarize(txnsOfDay(day));

  /// 按月内每天聚合，缺失日期补 0，保证柱状图横轴连续。
  List<TrendPoint> dailyTrend(int year, int month) {
    final buckets = <String, List<Txn>>{};
    for (final t in _txns) {
      final d = t.dayDate;
      if (d.year == year && d.month == month) {
        buckets.putIfAbsent(t.day, () => []).add(t);
      }
    }
    final count = _daysInMonth(year, month);
    return List.generate(count, (i) {
      final day = dayKey(DateTime(year, month, i + 1));
      final s = summarize(buckets[day] ?? const []);
      return TrendPoint('${i + 1}', s.expense, s.income);
    });
  }

  List<TrendPoint> monthlyTrend(int year) {
    final buckets = <int, List<Txn>>{};
    for (final t in _txns) {
      final d = t.dayDate;
      if (d.year == year) buckets.putIfAbsent(d.month, () => []).add(t);
    }
    return List.generate(12, (i) {
      final s = summarize(buckets[i + 1] ?? const []);
      return TrendPoint('${i + 1}', s.expense, s.income);
    });
  }

  Summary summaryOfMonth(int year, int month) => summarize(
    _txns.where((t) {
      final d = t.dayDate;
      return d.year == year && d.month == month;
    }),
  );

  Summary summaryOfYear(int year) =>
      summarize(_txns.where((t) => t.dayDate.year == year));

  /// 账本中出现过的年份，倒序；无数据时只含今年。
  List<int> get years {
    final set = _txns.map((t) => t.dayDate.year).toSet();
    set.add(DateTime.now().year);
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  List<DayGroup> get dayGroups {
    final buckets = <String, List<Txn>>{};
    for (final t in _txns) {
      buckets.putIfAbsent(t.day, () => []).add(t);
    }
    final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys.map((k) {
      final list = buckets[k]!;
      final s = summarize(list);
      return DayGroup(DateTime.parse(k), list, s.expense, s.income);
    }).toList();
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}

List<Txn> _demoTxns() {
  final now = DateTime.now();
  var seed = 7;
  double next(double lo, double hi) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return lo + (seed % 10000) / 10000 * (hi - lo);
  }

  final result = <Txn>[];
  // 近 14 个月的日常支出 + 每月工资，便于日/月/年三种视图都有内容。
  for (var back = 13; back >= 0; back--) {
    final month = DateTime(now.year, now.month - back);
    final daysInMonth = LedgerStore._daysInMonth(month.year, month.month);
    final lastDay = month.isAtSameMomentAs(DateTime(now.year, now.month))
        ? now.day
        : daysInMonth;
    result.add(
      Txn(
        type: TxnType.income,
        categoryKey: 'salary',
        amount: 12000 + (month.month % 3) * 600,
        day: dayKey(DateTime(month.year, month.month, 10)),
        createdAt: DateTime(month.year, month.month, 10).millisecondsSinceEpoch,
      ),
    );
    if (month.month % 4 == 0) {
      result.add(
        Txn(
          type: TxnType.income,
          categoryKey: 'investment',
          amount: next(300, 2600),
          day: dayKey(DateTime(month.year, month.month, 18)),
          createdAt: DateTime(month.year, month.month, 18).millisecondsSinceEpoch,
        ),
      );
    }
    const spendCats = [
      ('food', 18.0, 160.0),
      ('transport', 6.0, 45.0),
      ('shopping', 60.0, 680.0),
      ('entertainment', 20.0, 220.0),
      ('medical', 30.0, 400.0),
      ('study', 40.0, 300.0),
      ('beauty', 80.0, 900.0),
    ];
    var createdBase = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
    for (var d = 1; d <= lastDay; d++) {
      final day = DateTime(month.year, month.month, d);
      final items = <(String, double)>[];
      for (final (key, lo, hi) in spendCats) {
        final chance = key == 'food' ? 0.85 : 0.18;
        if (next(0, 1) < chance) {
          items.add((key, next(lo, hi)));
        }
      }
      if (day.day % 5 == 0) items.add(('housing', next(900, 2600)));
      for (var i = 0; i < items.length; i++) {
        result.add(
          Txn(
            type: TxnType.expense,
            categoryKey: items[i].$1,
            amount: double.parse(items[i].$2.toStringAsFixed(2)),
            day: dayKey(day),
            createdAt: createdBase + d * 100000 + i * 1000,
          ),
        );
      }
    }
  }
  return result;
}
