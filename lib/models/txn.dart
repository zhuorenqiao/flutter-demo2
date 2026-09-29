import 'package:flutter/material.dart';

enum TxnType { expense, income }

class TxnCategory {
  const TxnCategory(this.key, this.label, this.icon, this.color);

  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

const List<TxnCategory> kExpenseCategories = [
  TxnCategory('food', '餐饮', Icons.restaurant, Color(0xFFFF7A45)),
  TxnCategory('transport', '交通', Icons.local_taxi, Color(0xFF2FA8FF)),
  TxnCategory('shopping', '购物', Icons.shopping_bag, Color(0xFFA855F7)),
  TxnCategory('housing', '居住', Icons.home, Color(0xFF14C3A2)),
  TxnCategory('entertainment', '娱乐', Icons.sports_esports, Color(0xFFFFC53D)),
  TxnCategory('medical', '医疗', Icons.local_hospital, Color(0xFFFF4D6D)),
  TxnCategory('study', '学习', Icons.menu_book, Color(0xFF4C6EF5)),
  TxnCategory('beauty', '服饰美容', Icons.checkroom, Color(0xFFF06595)),
  TxnCategory('other_expense', '其他', Icons.more_horiz, Color(0xFF8C9BAB)),
];

const List<TxnCategory> kIncomeCategories = [
  TxnCategory('salary', '工资', Icons.badge, Color(0xFF22C55E)),
  TxnCategory('bonus', '奖金', Icons.card_giftcard, Color(0xFFFB923C)),
  TxnCategory('part_time', '兼职', Icons.work, Color(0xFF06B6D4)),
  TxnCategory('investment', '理财', Icons.trending_up, Color(0xFF8B5CF6)),
  TxnCategory('other_income', '其他', Icons.savings, Color(0xFF8C9BAB)),
];

TxnCategory categoryOf(String key) {
  return [...kExpenseCategories, ...kIncomeCategories].firstWhere(
    (c) => c.key == key,
    orElse: () => kExpenseCategories.last,
  );
}

List<TxnCategory> categoriesOf(TxnType type) =>
    type == TxnType.expense ? kExpenseCategories : kIncomeCategories;

class Txn {
  const Txn({
    this.id,
    required this.type,
    required this.categoryKey,
    required this.amount,
    required this.day,
    required this.createdAt,
    this.note = '',
  });

  final int? id;
  final TxnType type;
  final String categoryKey;
  final double amount;

  /// 记账日期，格式 yyyy-MM-dd
  final String day;
  final int createdAt;
  final String note;

  TxnCategory get category => categoryOf(categoryKey);

  DateTime get dayDate => DateTime.parse(day);

  Txn copyWith({double? amount, String? day, String? note}) => Txn(
    id: id,
    type: type,
    categoryKey: categoryKey,
    amount: amount ?? this.amount,
    day: day ?? this.day,
    createdAt: createdAt,
    note: note ?? this.note,
  );
}

/// yyyy-MM-dd
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String formatDay(DateTime d) => '${d.year}年${d.month}月${d.day}日';

String formatMonth(DateTime d) => '${d.year}年${d.month}月';

String formatMoney(double v) => v.toStringAsFixed(2);

String weekdayLabel(DateTime d) =>
    const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][d.weekday - 1];
