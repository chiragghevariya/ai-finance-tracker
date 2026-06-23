<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Budget;
use App\Models\Transaction;
use App\Rules\ValidCategory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BudgetController extends Controller
{
    /**
     * POST /api/budgets
     * Create or update a budget (a spending limit) for a category in a month/year.
     *
     * Posting the same category + month + year again simply updates the existing
     * limit instead of creating a duplicate (thanks to updateOrCreate()).
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            // category_id is optional: leave it out (null) for an OVERALL monthly budget.
            // ValidCategory makes sure it's a default category or one this user owns.
            'category_id'  => ['nullable', 'integer', new ValidCategory()],
            'month'        => ['required', 'integer', 'between:1,12'],
            'year'         => ['required', 'integer', 'between:2000,2100'],
            'limit_amount' => ['required', 'numeric', 'min:0'],
        ]);

        $budget = Budget::updateOrCreate(
            // Match on these columns...
            [
                'user_id'     => auth('api')->id(),
                'category_id' => $data['category_id'] ?? null,
                'month'       => $data['month'],
                'year'        => $data['year'],
            ],
            // ...and set/refresh this value.
            ['limit_amount' => $data['limit_amount']],
        );

        return response()->json($budget->load('category'), 201);
    }

    /**
     * GET /api/budgets?month=12&year=2026
     * List the user's budgets for a month/year, each enriched with how much has
     * actually been spent so far and how much remains.
     */
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'month' => ['required', 'integer', 'between:1,12'],
            'year'  => ['required', 'integer', 'between:2000,2100'],
        ]);

        $userId = auth('api')->id();

        $budgets = Budget::query()
            ->where('user_id', $userId)
            ->where('month', $data['month'])
            ->where('year', $data['year'])
            ->with('category:id,name,color,icon')
            ->get()
            ->map(function (Budget $budget) use ($userId, $data) {
                // Work out how much the user has already spent against this budget.
                $spentQuery = Transaction::query()
                    ->where('user_id', $userId)
                    ->where('type', 'expense')
                    ->whereMonth('date', $data['month'])
                    ->whereYear('date', $data['year']);

                // A category budget only counts that category's expenses.
                // An overall budget (category_id = null) counts ALL expenses.
                if ($budget->category_id !== null) {
                    $spentQuery->where('category_id', $budget->category_id);
                }

                $spent = (float) $spentQuery->sum('amount');
                $limit = (float) $budget->limit_amount;

                return [
                    'id'           => $budget->id,
                    'category'     => $budget->category, // null = overall budget
                    'month'        => $budget->month,
                    'year'         => $budget->year,
                    'limit_amount' => round($limit, 2),
                    'spent'        => round($spent, 2),
                    'remaining'    => round($limit - $spent, 2), // negative = over budget
                ];
            });

        return response()->json($budgets);
    }
}
