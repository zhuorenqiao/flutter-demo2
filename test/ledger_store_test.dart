import 'package:flutter_demo2/models/txn.dart';
import 'package:flutter_demo2/state/ledger_store.dart';
import 'package:flutter_test/flutter_test.dart';

Txn expense(String categoryKey, double amount, String day) => Txn(
  type: TxnType.expense,
  categoryKey: categoryKey,
  amount: amount,
  day: day,
  createdAt: 0,
);

void main() {
  group('LedgerStore.summarize', () {
    test('按类型汇总并给出分类明细', () {
      final s = LedgerStore.summarize([
        expense('food', 30, '2026-09-01'),
        expense('food', 20, '2026-09-02'),
        expense('transport', 15, '2026-09-02'),
        Txn(
          type: TxnType.income,
          categoryKey: 'salary',
          amount: 1000,
          day: '2026-09-10',
          createdAt: 0,
        ),
      ]);

      expect(s.expense, 65);
      expect(s.income, 1000);
      expect(s.balance, 935);
      expect(s.expenseByCategory.first.category.key, 'food');
      expect(s.expenseByCategory.first.amount, 50);
      expect(s.count, 4);
    });

    test('空账本得到全零结果', () {
      final s = LedgerStore.summarize(const []);
      expect(s.expense, 0);
      expect(s.income, 0);
      expect(s.expenseByCategory, isEmpty);
    });
  });

  test('dayKey 固定为 yyyy-MM-dd', () {
    expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
