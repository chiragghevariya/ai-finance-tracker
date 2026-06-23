<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Regression tests for the category-ownership fix.
 *
 * A user must NOT be able to attach a transaction to another user's private
 * category, but SHOULD be able to use default categories or their own.
 */
class CategoryOwnershipTest extends TestCase
{
    use RefreshDatabase;

    /** A helper to POST a transaction with a given category id as a given user. */
    private function postTransactionAs(User $user, ?int $categoryId)
    {
        return $this->actingAs($user, 'api')->postJson('/api/transactions', [
            'type'        => 'expense',
            'amount'      => 10,
            'description' => 'Test expense',
            'date'        => '2026-06-01',
            'category_id' => $categoryId,
        ]);
    }

    public function test_user_cannot_use_another_users_private_category(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        // Bob's private category.
        $bobCategory = Category::create([
            'user_id' => $bob->id, 'name' => 'Bob Secret', 'icon' => '🔒', 'color' => '#000000', 'is_default' => false,
        ]);

        // Alice tries to use it -> rejected by validation.
        $this->postTransactionAs($alice, $bobCategory->id)->assertStatus(422);
    }

    public function test_user_can_use_a_default_category(): void
    {
        $alice = User::factory()->create();
        $food  = Category::create([
            'name' => 'Food', 'icon' => '🍔', 'color' => '#FF7043', 'is_default' => true, // user_id is null
        ]);

        $this->postTransactionAs($alice, $food->id)->assertCreated();
    }

    public function test_user_can_use_their_own_category(): void
    {
        $alice = User::factory()->create();
        $mine  = Category::create([
            'user_id' => $alice->id, 'name' => 'Mine', 'icon' => '⭐', 'color' => '#111111', 'is_default' => false,
        ]);

        $this->postTransactionAs($alice, $mine->id)->assertCreated();
    }
}
