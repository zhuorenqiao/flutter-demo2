import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/txn.dart';
import '../state/ledger_store.dart';

/// 收支概览卡片
class SummaryCards extends StatelessWidget {
  const SummaryCards({super.key, required this.summary, this.subtitle});

  final Summary summary;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                _cell(context, '支出', summary.expense, const Color(0xFFE53935)),
                _divider(context),
                _cell(context, '收入', summary.income, const Color(0xFF43A047)),
                _divider(context),
                _cell(
                  context,
                  '结余',
                  summary.balance,
                  summary.balance >= 0
                      ? const Color(0xFF1E88E5)
                      : const Color(0xFFFB8C00),
                ),
              ],
            ),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              '$subtitle · ${summary.count} 笔',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _divider(BuildContext context) => Container(
    width: 1,
    height: 34,
    color: Theme.of(context).dividerColor,
  );

  Widget _cell(BuildContext context, String label, double value, Color color) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              formatMoney(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

/// 分类占比饼图 + 图例
class CategoryPieCard extends StatelessWidget {
  const CategoryPieCard({super.key, required this.title, required this.slices});

  final String title;
  final List<CategorySlice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (a, s) => a + s.amount);
    return _Card(
      title: title,
      child: slices.isEmpty || total <= 0
          ? const _Empty(msg: '这段时间还没有数据')
          : Column(
              children: [
                SizedBox(
                  height: 190,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 42,
                      sections: [
                        for (final s in slices)
                          PieChartSectionData(
                            value: s.amount,
                            color: s.category.color,
                            radius: 58,
                            title: (s.amount / total * 100).toStringAsFixed(0),
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final s in slices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.category.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(s.category.label),
                        const Spacer(),
                        Text(
                          formatMoney(s.amount),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            '${(s.amount / total * 100).toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 趋势柱状图：支出/收入并排
class TrendBarCard extends StatelessWidget {
  const TrendBarCard({
    super.key,
    required this.title,
    required this.points,
    required this.unitLabel,
    this.tooltipWithoutSuffix = false,
  });

  final String title;
  final List<TrendPoint> points;
  final String unitLabel;
  final bool tooltipWithoutSuffix;

  @override
  Widget build(BuildContext context) {
    final maxV = points.fold<double>(
      0,
      (a, p) => [a, p.expense, p.income].reduce((x, y) => x > y ? x : y),
    );
    final hasData = maxV > 0;
    return _Card(
      title: title,
      child: SizedBox(
        height: 220,
        child: !hasData
            ? const _Empty(msg: '这段时间还没有数据')
            : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxV * 1.15,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          Theme.of(context).colorScheme.inverseSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                            '${group.x + 1}$unitLabel  ${rodIndex == 0 ? '支出' : '收入'}：${rod.toY.toStringAsFixed(2)}',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                    ),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxV / 4,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            _short(v),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        // 数据点很多时隔级显示，避免标签重叠
                        interval: points.length > 16 ? 5.0 : 1.0,
                        getTitlesWidget: (v, _) {
                          final i = v.round();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              points[i].label,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].expense,
                            color: const Color(0xFFE53935),
                            width: points.length > 16 ? 3 : 7,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                          ),
                          BarChartRodData(
                            toY: points[i].income,
                            color: const Color(0xFF43A047),
                            width: points.length > 16 ? 3 : 7,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  static String _short(double v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

/// 支出/收入图例说明
class LegendRow extends StatelessWidget {
  const LegendRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(context, const Color(0xFFE53935), '支出'),
        const SizedBox(width: 16),
        _dot(context, const Color(0xFF43A047), '收入'),
      ],
    );
  }

  Widget _dot(BuildContext context, Color color, String label) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        color: color,
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.msg});

  final String msg;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(msg, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
