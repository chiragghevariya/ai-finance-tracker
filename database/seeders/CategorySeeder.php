<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;

/**
 * Seeds the 10 built-in default categories that every user sees.
 *
 * Default categories have:
 *   - user_id    = null  (they belong to nobody in particular / are shared)
 *   - is_default = true
 */
class CategorySeeder extends Seeder
{
    public function run(): void
    {
        $defaults = [
            ['name' => 'Food',          'icon' => '🍔', 'color' => '#FF7043'],
            ['name' => 'Transport',     'icon' => '🚗', 'color' => '#42A5F5'],
            ['name' => 'Shopping',      'icon' => '🛍️', 'color' => '#AB47BC'],
            ['name' => 'Health',        'icon' => '💊', 'color' => '#EF5350'],
            ['name' => 'Entertainment', 'icon' => '🎬', 'color' => '#FFCA28'],
            ['name' => 'Housing',       'icon' => '🏠', 'color' => '#8D6E63'],
            ['name' => 'Utilities',     'icon' => '⚡', 'color' => '#26C6DA'],
            ['name' => 'Education',     'icon' => '📚', 'color' => '#66BB6A'],
            ['name' => 'Travel',        'icon' => '✈️', 'color' => '#5C6BC0'],
            ['name' => 'Other',         'icon' => '💼', 'color' => '#9E9E9E'],
        ];

        foreach ($defaults as $category) {
            // updateOrCreate makes this seeder safe to run more than once:
            // it updates the existing default category instead of creating a duplicate.
            Category::updateOrCreate(
                // Find an existing default category with this name...
                ['name' => $category['name'], 'user_id' => null, 'is_default' => true],
                // ...and set its icon + colour.
                ['icon' => $category['icon'], 'color' => $category['color']],
            );
        }
    }
}
