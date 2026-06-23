<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Transaction;
use App\Rules\ValidCategory;
use App\Services\OpenAiService;
use App\Services\SummaryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use OpenAI\Laravel\Exceptions\ApiKeyIsMissing;

/**
 * Full CRUD for transactions, plus the monthly summary endpoint.
 *
 * Security rule for the whole controller: a user may only ever see or change
 * their OWN transactions. We enforce this by always scoping queries to
 * auth('api')->id() and by checking ownership before show/update/delete.
 */
class TransactionController extends Controller
{
    /**
     * GET /api/transactions
     * List the logged-in user's transactions (newest first), with optional filters:
     *   ?type=expense  ?category_id=3  ?month=12  ?year=2026
     */
    public function index(Request $request): JsonResponse
    {
        $query = Transaction::query()
            ->where('user_id', auth('api')->id())  // only THIS user's data
            ->with('category:id,name,color,icon')   // include category details
            ->orderByDesc('date')
            ->orderByDesc('id');

        // Each filter is only applied if that query parameter was actually sent.
        if ($request->filled('type')) {
            $query->where('type', $request->input('type'));
        }
        if ($request->filled('category_id')) {
            $query->where('category_id', $request->integer('category_id'));
        }
        if ($request->filled('month')) {
            $query->whereMonth('date', $request->integer('month'));
        }
        if ($request->filled('year')) {
            $query->whereYear('date', $request->integer('year'));
        }

        // Paginate (15 per page) so we never dump thousands of rows in one response.
        return response()->json($query->paginate(15));
    }

    /**
     * POST /api/transactions
     * Create a new transaction for the logged-in user.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $this->validateData($request);

        // If a receipt photo was uploaded, store it on the "public" disk and keep its path.
        if ($request->hasFile('receipt_image')) {
            $data['receipt_image'] = $request->file('receipt_image')->store('receipts', 'public');
        }

        // Always force the owner to be the logged-in user.
        // (Never trust a user_id sent by the client.)
        $data['user_id'] = auth('api')->id();

        $transaction = Transaction::create($data);

        return response()->json($transaction->load('category'), 201);
    }

    /**
     * GET /api/transactions/{transaction}
     * Show a single transaction (only if it belongs to the user).
     */
    public function show(Transaction $transaction): JsonResponse
    {
        $this->authorizeOwner($transaction);

        return response()->json($transaction->load('category'));
    }

    /**
     * PUT/PATCH /api/transactions/{transaction}
     * Update a transaction (only if it belongs to the user).
     */
    public function update(Request $request, Transaction $transaction): JsonResponse
    {
        $this->authorizeOwner($transaction);

        $data = $this->validateData($request);

        if ($request->hasFile('receipt_image')) {
            $data['receipt_image'] = $request->file('receipt_image')->store('receipts', 'public');
        }

        $transaction->update($data);

        return response()->json($transaction->load('category'));
    }

    /**
     * DELETE /api/transactions/{transaction}
     * Delete a transaction (only if it belongs to the user).
     */
    public function destroy(Transaction $transaction): JsonResponse
    {
        $this->authorizeOwner($transaction);

        $transaction->delete();

        return response()->json(['message' => 'Transaction deleted.']);
    }

    /**
     * GET /api/transactions/summary?month=12&year=2026
     * Returns total_income, total_expense, balance and a by_category array.
     *
     * The SummaryService is automatically injected by Laravel's service container.
     */
    public function summary(Request $request, SummaryService $summary): JsonResponse
    {
        // Fall back to the current month/year if the client didn't specify them.
        $month = (int) $request->input('month', now()->month);
        $year  = (int) $request->input('year', now()->year);

        return response()->json(
            $summary->monthlySummary(auth('api')->id(), $month, $year)
        );
    }

    /**
     * POST /api/transactions/auto-categorize
     * Body: { "description": "McDonald's lunch" }
     *
     * Asks OpenAI to pick the best category (from the user's own list) for a given
     * description, and returns the suggested category id. This powers the "smart
     * categorize" button in the app — the user can accept or change the suggestion.
     */
    public function autoCategorize(Request $request, OpenAiService $ai): JsonResponse
    {
        $data = $request->validate([
            'description' => ['required', 'string', 'max:255'],
        ]);

        // Make sure OpenAI is configured before we try to use it.
        if (blank(config('openai.api_key'))) {
            return response()->json([
                'message' => 'OpenAI API key is not configured. Add OPENAI_API_KEY to your .env file.',
            ], 503);
        }

        // The categories this user may choose from: shared defaults + their own.
        $categories = Category::query()
            ->where(function ($query) {
                $query->whereNull('user_id')->orWhere('user_id', auth('api')->id());
            })
            ->get(['id', 'name']);

        try {
            $suggestedId = $ai->suggestCategory($data['description'], $categories->toArray());
        } catch (ApiKeyIsMissing $e) {
            return response()->json(['message' => 'OpenAI API key is not configured.'], 503);
        } catch (\Throwable $e) {
            report($e); // log the real error for debugging
            return response()->json([
                'message' => 'Could not suggest a category. Please try again.',
                'error'   => config('app.debug') ? $e->getMessage() : null,
            ], 502);
        }

        // Safety check: only trust an id that is actually in the user's own list.
        $category = $categories->firstWhere('id', $suggestedId);

        return response()->json([
            'suggested_category_id' => $category?->id,
            'suggested_category'    => $category, // full {id, name}, or null if no match
        ]);
    }

    /**
     * Validation rules shared by store() and update().
     *
     * @return array<string, mixed>
     */
    protected function validateData(Request $request): array
    {
        return $request->validate([
            'type'          => ['required', 'in:income,expense'],
            'amount'        => ['required', 'numeric', 'min:0.01'],
            'description'   => ['required', 'string', 'max:255'],
            'note'          => ['nullable', 'string'],
            'date'          => ['required', 'date'],
            // category_id is optional. ValidCategory checks it's a default category
            // or one this user owns (not another user's private category).
            'category_id'   => ['nullable', 'integer', new ValidCategory()],
            // Optional uploaded receipt photo, max ~5 MB.
            'receipt_image' => ['nullable', 'image', 'max:5120'],
        ]);
    }

    /**
     * Stop the request with a 403 Forbidden unless the transaction belongs to the
     * logged-in user. This prevents one user from touching another user's data.
     */
    protected function authorizeOwner(Transaction $transaction): void
    {
        abort_unless(
            $transaction->user_id === auth('api')->id(),
            403,
            'This transaction does not belong to you.'
        );
    }
}
