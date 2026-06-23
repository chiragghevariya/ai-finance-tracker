<?php

namespace App\Rules;

use App\Models\Category;
use Closure;
use Illuminate\Contracts\Validation\ValidationRule;

/**
 * Validates that a category_id is one the logged-in user is actually allowed to use.
 *
 * A category is allowed when it is:
 *   - null / empty          (the transaction or budget simply has no category), OR
 *   - a DEFAULT category    (user_id is null — shared by everyone), OR
 *   - a CUSTOM category     owned by the logged-in user.
 *
 * Why this exists:
 * The plain 'exists:categories,id' rule only checks that the id exists *somewhere*.
 * That would let a user attach their transaction/budget to ANOTHER user's private
 * category and read back its details (name, colour, icon). This rule closes that hole.
 */
class ValidCategory implements ValidationRule
{
    /**
     * @param  string   $attribute  the field name being validated (e.g. "category_id")
     * @param  mixed    $value      the value the client sent
     * @param  Closure  $fail       call this with a message to mark the field invalid
     */
    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        // No category chosen — that's allowed, nothing to check.
        if ($value === null || $value === '') {
            return;
        }

        $userId = auth('api')->id();

        // The category must exist AND be either shared (default) or owned by this user.
        $isAllowed = Category::query()
            ->where('id', $value)
            ->where(function ($query) use ($userId) {
                $query->whereNull('user_id')        // default / shared category
                    ->orWhere('user_id', $userId);  // this user's own category
            })
            ->exists();

        if (! $isAllowed) {
            $fail('The selected category is invalid.');
        }
    }
}
