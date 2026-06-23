<?php

namespace App\Services;

use App\Models\Transaction;

/**
 * Calculates a user's monthly financial summary:
 *   - total income
 *   - total expense
 *   - balance (income - expense)
 *   - a per-category breakdown of expenses (great for pie/bar charts)
 *
 * We keep this logic in a dedicated service (instead of the controller) so it stays
 * easy to read, easy to test, and reusable — for example the OpenAI assistant in a
 * later phase can call this to get the numbers it needs to talk about the user's money.
 */
class SummaryService
{
    /**
     * Build the summary for one user, for one month + year.
     *
     * @param  int  $userId  whose transactions to summarise
     * @param  int  $month   1..12
     * @param  int  $year    e.g. 2026
     * @return array<string, mixed>
     */
    public function monthlySummary(int $userId, int $month, int $year): array
    {
        // Base query: this user's transactions that fall inside the requested month + year.
        $base = Transaction::query()
            ->where('user_id', $userId)
            ->whereMonth('date', $month)
            ->whereYear('date', $year);

        // Total money IN and money OUT for the month.
        // We clone the base query each time because running sum() "consumes" the query.
        $totalIncome  = (float) (clone $base)->where('type', 'income')->sum('amount');
        $totalExpense = (float) (clone $base)->where('type', 'expense')->sum('amount');

        // Group EXPENSES by category so the app can draw a spending chart.
        $byCategory = (clone $base)
            ->where('type', 'expense')
            ->selectRaw('category_id, SUM(amount) as total, COUNT(*) as count')
            ->groupBy('category_id')
            ->with('category:id,name,color,icon') // eager-load each category's details
            ->get()
            ->map(function ($row) use ($totalExpense) {
                $rowTotal = (float) $row->total;

                return [
                    'category_id' => $row->category_id,
                    // If the expense had no category, show a friendly fallback label.
                    'name'        => $row->category?->name ?? 'Uncategorized',
                    'color'       => $row->category?->color,
                    'icon'        => $row->category?->icon,
                    'total'       => round($rowTotal, 2),
                    'count'       => (int) $row->count,
                    // What share (0..100) of total expenses this category represents.
                    'percentage'  => $totalExpense > 0
                        ? round(($rowTotal / $totalExpense) * 100, 1)
                        : 0,
                ];
            })
            ->sortByDesc('total') // biggest spenders first
            ->values();           // re-index the collection to 0,1,2,...

        return [
            'month'         => $month,
            'year'          => $year,
            'total_income'  => round($totalIncome, 2),
            'total_expense' => round($totalExpense, 2),
            // Balance can be negative if you spent more than you earned this month.
            'balance'       => round($totalIncome - $totalExpense, 2),
            'by_category'   => $byCategory,
        ];
    }
}
