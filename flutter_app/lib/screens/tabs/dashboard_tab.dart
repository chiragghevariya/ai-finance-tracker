import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/category_pie_chart.dart';
import '../../widgets/transaction_card.dart';

/// Tab 1 — an overview: balance card, spending pie chart, recent transactions.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          final summary = provider.summary;
          final recent = provider.recentTransactions;

          // First load with no data yet -> show a spinner.
          if (provider.isLoading && recent.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- Balance card ---
                BalanceCard(
                  income: summary.totalIncome,
                  expense: summary.totalExpense,
                  balance: summary.balance,
                  monthLabel: formatMonthYear(provider.month, provider.year),
                ),
                const SizedBox(height: 24),

                // --- Spending by category (pie chart) ---
                const _SectionTitle('Spending by category'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CategoryPieChart(data: summary.byCategory),
                  ),
                ),
                const SizedBox(height: 24),

                // --- Recent transactions ---
                const _SectionTitle('Recent transactions'),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No transactions yet.\nTap + to add your first one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  ...recent.map((t) => TransactionCard(transaction: t)),

                const SizedBox(height: 80), // space so the FAB doesn't overlap
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}
