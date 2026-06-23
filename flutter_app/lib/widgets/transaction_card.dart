import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/transaction.dart';
import '../utils/color_utils.dart';
import '../utils/formatters.dart';

/// A single row in any transaction list:
///   [icon]  Description            +/-$amount
///           Category • date
///
/// The amount is green for income and red for expense.
class TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionCard({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    final category = transaction.category;
    final circleColor = hexToColor(category?.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: circleColor.withOpacity(0.15),
          child: Text(
            category?.icon ?? '💼',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          transaction.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${category?.name ?? 'Uncategorized'} • ${formatDate(transaction.date)}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: Text(
          formatSignedMoney(transaction.amount, isIncome: isIncome),
          style: TextStyle(
            color: amountColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
