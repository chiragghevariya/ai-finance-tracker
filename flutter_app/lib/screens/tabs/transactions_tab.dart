import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/transaction_card.dart';
import '../transaction_detail_screen.dart';

/// Tab 2 — the full transaction list with a month selector and type filter.
class TransactionsTab extends StatelessWidget {
  const TransactionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _MonthSelector(provider: provider),
              _TypeFilterChips(provider: provider),
              const Divider(height: 1),
              Expanded(child: _TransactionList(provider: provider)),
            ],
          );
        },
      ),
    );
  }
}

/// "< June 2026 >" month switcher.
class _MonthSelector extends StatelessWidget {
  final TransactionProvider provider;
  const _MonthSelector({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => provider.changeMonth(-1),
          ),
          Text(
            formatMonthYear(provider.month, provider.year),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => provider.changeMonth(1),
          ),
        ],
      ),
    );
  }
}

/// All / Income / Expense filter chips.
class _TypeFilterChips extends StatelessWidget {
  final TransactionProvider provider;
  const _TypeFilterChips({required this.provider});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, TypeFilter value) {
      final selected = provider.typeFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => provider.setTypeFilter(value),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            chip('All', TypeFilter.all),
            chip('Income', TypeFilter.income),
            chip('Expense', TypeFilter.expense),
          ],
        ),
      ),
    );
  }
}

/// The scrollable list, with swipe-to-delete and pull-to-refresh.
class _TransactionList extends StatelessWidget {
  final TransactionProvider provider;
  const _TransactionList({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.transactions.isEmpty) {
      // Still allow pull-to-refresh even when empty.
      return RefreshIndicator(
        onRefresh: provider.refresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'No transactions for this month.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        itemCount: provider.transactions.length,
        itemBuilder: (context, index) {
          final TransactionModel t = provider.transactions[index];
          return Dismissible(
            key: ValueKey(t.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.expense,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) => _confirmDelete(context),
            onDismissed: (_) => provider.deleteTransaction(t.id),
            child: TransactionCard(
              transaction: t,
              onTap: () => TransactionDetailScreen.navigate(context, t),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
