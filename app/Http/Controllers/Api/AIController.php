<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use App\Services\OpenAiService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use OpenAI\Laravel\Exceptions\ApiKeyIsMissing;

/**
 * The "chat with your finances" feature.
 *
 * The user asks a question in plain English; we attach a summary of their recent
 * spending as context and let OpenAI answer it.
 */
class AIController extends Controller
{
    /**
     * POST /api/ai/chat
     * Body: { "message": "Where did I spend most last month?" }
     */
    public function chat(Request $request, OpenAiService $ai): JsonResponse
    {
        $data = $request->validate([
            'message' => ['required', 'string', 'max:1000'],
        ]);

        // Make sure OpenAI is configured before we try to use it.
        if (blank(config('openai.api_key'))) {
            return response()->json([
                'message' => 'OpenAI API key is not configured. Add OPENAI_API_KEY to your .env file.',
            ], 503);
        }

        // Build a text summary of the user's last 3 months of spending. This is the
        // "context" the AI uses to answer — it never sees the raw database.
        $context = $this->buildContext(auth('api')->id());

        try {
            $reply = $ai->chat($data['message'], $context);
        } catch (ApiKeyIsMissing $e) {
            return response()->json(['message' => 'OpenAI API key is not configured.'], 503);
        } catch (\Throwable $e) {
            report($e); // log the real error for debugging
            return response()->json([
                'message' => 'The AI assistant is unavailable right now. Please try again.',
                'error'   => config('app.debug') ? $e->getMessage() : null,
            ], 502);
        }

        return response()->json(['reply' => $reply]);
    }

    /**
     * Build a short, readable summary of the user's last 3 months of transactions.
     * Summarising (instead of sending every row) keeps the request small and cheap.
     */
    protected function buildContext(int $userId): string
    {
        // First day of the month, two months back -> covers this month + the 2 before it.
        $since = now()->startOfMonth()->subMonths(2)->toDateString();

        $transactions = Transaction::query()
            ->where('user_id', $userId)
            ->where('date', '>=', $since)
            ->with('category:id,name')
            ->orderBy('date')
            ->get();

        if ($transactions->isEmpty()) {
            return 'The user has no transactions in the last 3 months.';
        }

        // 1) Income vs expense totals for each month, e.g. "2026-05: income 2000.00, expense 750.00".
        $byMonth = $transactions
            ->groupBy(fn ($t) => $t->date->format('Y-m'))
            ->map(function ($rows, $month) {
                $income  = $rows->where('type', 'income')->sum('amount');
                $expense = $rows->where('type', 'expense')->sum('amount');

                return "- {$month}: income ".number_format($income, 2).', expense '.number_format($expense, 2);
            })
            ->implode("\n");

        // 2) Total spent per category, biggest first.
        $byCategory = $transactions
            ->where('type', 'expense')
            ->groupBy(fn ($t) => $t->category?->name ?? 'Uncategorized')
            ->map(fn ($rows, $name) => ['name' => $name, 'total' => $rows->sum('amount')])
            ->sortByDesc('total')
            ->map(fn ($c) => "- {$c['name']}: ".number_format($c['total'], 2))
            ->implode("\n");

        // 3) The 15 most recent transactions, for a bit of detail.
        $recent = $transactions
            ->sortByDesc('date')
            ->take(15)
            ->map(function ($t) {
                $category = $t->category?->name ?? 'Uncategorized';

                return "- {$t->date->format('Y-m-d')} {$t->type} "
                    .number_format($t->amount, 2)." {$category} \"{$t->description}\"";
            })
            ->implode("\n");

        return "Monthly totals:\n{$byMonth}\n\n"
            ."Expenses by category:\n{$byCategory}\n\n"
            ."Recent transactions:\n{$recent}";
    }
}
