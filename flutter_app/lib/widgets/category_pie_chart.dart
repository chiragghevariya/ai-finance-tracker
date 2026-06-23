import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/summary.dart';
import '../utils/color_utils.dart';
import '../utils/formatters.dart';

/// A pie chart of spending by category, with a legend underneath.
/// Built from the `by_category` array of the monthly summary.
class CategoryPieChart extends StatelessWidget {
  final List<CategorySummary> data;

  const CategoryPieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Nothing spent yet this month — show a friendly placeholder.
    if (data.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No expenses yet this month',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    // Build one pie slice per category.
    final sections = data.map((c) {
      return PieChartSectionData(
        value: c.total,
        color: hexToColor(c.color),
        title: '${c.percentage.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend: a colour dot + icon + name + amount for each category.
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: data.map((c) => _LegendItem(category: c)).toList(),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final CategorySummary category;

  const _LegendItem({required this.category});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: hexToColor(category.color),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${category.icon ?? ''} ${category.name}: ${formatMoney(category.total)}',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
