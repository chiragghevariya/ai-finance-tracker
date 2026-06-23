<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\JsonResponse;

class CategoryController extends Controller
{
    /**
     * GET /api/categories
     *
     * Returns the categories the logged-in user can choose from:
     *   - the 10 shared DEFAULT categories (user_id = null), AND
     *   - any CUSTOM categories the user created themselves.
     */
    public function index(): JsonResponse
    {
        $userId = auth('api')->id();

        $categories = Category::query()
            // Group the OR so we never accidentally return someone else's categories.
            ->where(function ($query) use ($userId) {
                $query->whereNull('user_id')        // shared default categories
                    ->orWhere('user_id', $userId);  // this user's own categories
            })
            ->orderByDesc('is_default') // show the defaults first
            ->orderBy('name')           // then alphabetically
            ->get();

        return response()->json($categories);
    }
}
