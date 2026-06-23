<?php

namespace Database\Seeders;

use App\Models\Budget;
use App\Models\Category;
use App\Models\Transaction;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * Creates a realistic demo account for showing the app off.
 *
 * Login:  demo@finance.com  /  password123
 *
 * It generates ~3 months of believable spending for one person ("Alex Morgan"):
 *   - a monthly salary (income)
 *   - fixed bills (rent, utilities, subscriptions, gym)
 *   - everyday spending across all categories (food, transport, shopping, ...)
 *   - monthly budgets for 5 categories
 *
 * The random numbers are seeded (mt_srand) so you get the SAME data every time
 * you run the seeder — handy for recording a consistent demo.
 */
class DemoSeeder extends Seeder
{
    public function run(): void
    {
        // Same "random" data on every run.
        mt_srand(2026);

        // 1. The demo user shown in the README.
        $user = User::updateOrCreate(
            ['email' => 'demo@finance.com'],
            [
                'name' => 'Alex Morgan',
                'password' => Hash::make('password123'),
                'monthly_budget' => 2500,
            ],
        );

        // Look up the default category ids by name (so we don't hard-code ids).
        $categories = Category::whereNull('user_id')->pluck('id', 'name')->all();

        // Start fresh if this seeder is run again for the demo user.
        Transaction::where('user_id', $user->id)->delete();
        Budget::where('user_id', $user->id)->delete();

        // 2. Generate three months of transactions: this month + the two before it.
        $today = Carbon::now();
        for ($monthsAgo = 0; $monthsAgo < 3; $monthsAgo++) {
            $monthStart = $today->copy()->startOfMonth()->subMonths($monthsAgo);
            // Current month: only up to today (so we don't invent future spending).
            // Older months: treat as full (capped at day 28 to stay valid for any month).
            $maxDay = ($monthsAgo === 0) ? $today->day : 28;

            $this->seedMonth($user->id, $categories, $monthStart->year, $monthStart->month, $maxDay);
        }

        // 3. Monthly budgets for 5 categories, for each of the three months.
        $budgetLimits = [
            'Food' => 500,
            'Transport' => 200,
            'Shopping' => 300,
            'Entertainment' => 150,
            'Utilities' => 220,
        ];
        for ($monthsAgo = 0; $monthsAgo < 3; $monthsAgo++) {
            $month = $today->copy()->subMonths($monthsAgo);
            foreach ($budgetLimits as $name => $limit) {
                if (! isset($categories[$name])) {
                    continue;
                }
                Budget::create([
                    'user_id' => $user->id,
                    'category_id' => $categories[$name],
                    'month' => $month->month,
                    'year' => $month->year,
                    'limit_amount' => $limit,
                ]);
            }
        }
    }

    /**
     * Build one month of transactions.
     *
     * @param  array<string, int>  $categories  category name => id
     * @param  int  $maxDay  highest day-of-month to use (so the current month stops at "today")
     */
    private function seedMonth(int $userId, array $categories, int $year, int $month, int $maxDay): void
    {
        // Collected rows: ['type','amount','description','category','day'].
        $rows = [];
        $highDay = min(28, $maxDay);

        // Adds a transaction, but skips it if its day is beyond what we allow
        // (this is how the current month stays "up to today").
        $add = function (string $type, float $amount, string $desc, ?string $category, int $day) use (&$rows, $maxDay) {
            if ($day < 1 || $day > $maxDay) {
                return;
            }
            $rows[] = compact('type', 'amount', 'desc', 'category', 'day');
        };

        // --- Income ---
        $add('income', $this->money(4200, 4500), 'Monthly Salary', null, 1);
        if (mt_rand(1, 3) === 1) { // a freelance gig some months
            $add('income', $this->money(300, 800), 'Freelance Project', null, mt_rand(10, 20));
        }

        // --- Fixed monthly bills ---
        $add('expense', $this->money(1150, 1250), 'Monthly Rent', 'Housing', 1);
        $add('expense', $this->money(45, 70), 'Electricity Bill', 'Utilities', mt_rand(8, 12));
        $add('expense', $this->money(35, 55), 'Internet Bill', 'Utilities', mt_rand(9, 13));
        $add('expense', $this->money(40, 70), 'Phone Bill', 'Utilities', mt_rand(11, 15));
        $add('expense', 15.99, 'Netflix Subscription', 'Entertainment', 3);
        $add('expense', 9.99, 'Spotify Premium', 'Entertainment', 5);
        $add('expense', $this->money(35, 45), 'Gym Membership', 'Health', 2);

        // --- Groceries (roughly weekly) ---
        $groceryStores = ['Whole Foods', "Trader Joe's", 'Local Grocery', 'Supermarket'];
        foreach ([4, 11, 18, 25] as $day) {
            $add('expense', $this->money(45, 95), $this->pick($groceryStores).' groceries', 'Food', $day);
        }

        // --- Dining out (frequent, smaller) ---
        $dining = ['Starbucks', "McDonald's", 'Chipotle', 'Local Cafe', 'Sushi Bar', 'Pizza Night', 'Thai Takeout'];
        for ($i = 0, $n = mt_rand(7, 10); $i < $n; $i++) {
            $add('expense', $this->money(6, 38), $this->pick($dining), 'Food', mt_rand(1, $highDay));
        }

        // --- Transport ---
        $transport = ['Gas Station', 'Uber ride', 'Parking', 'Bus Pass', 'Train Ticket'];
        for ($i = 0, $n = mt_rand(6, 9); $i < $n; $i++) {
            $add('expense', $this->money(8, 55), $this->pick($transport), 'Transport', mt_rand(1, $highDay));
        }

        // --- Shopping ---
        $shopping = ['Amazon order', 'Clothing Store', 'Electronics', 'Home Goods', 'Online Purchase'];
        for ($i = 0, $n = mt_rand(3, 5); $i < $n; $i++) {
            $add('expense', $this->money(20, 180), $this->pick($shopping), 'Shopping', mt_rand(1, $highDay));
        }

        // --- Entertainment (besides the subscriptions above) ---
        $entertainment = ['Cinema tickets', 'Concert', 'Steam Games', 'Bowling night'];
        for ($i = 0, $n = mt_rand(1, 3); $i < $n; $i++) {
            $add('expense', $this->money(12, 75), $this->pick($entertainment), 'Entertainment', mt_rand(1, $highDay));
        }

        // --- Occasional categories ---
        if (mt_rand(1, 2) === 1) {
            $add('expense', $this->money(15, 60), 'Pharmacy', 'Health', mt_rand(1, $highDay));
        }
        if (mt_rand(1, 2) === 1) {
            $add('expense', $this->money(20, 120), 'Online Course', 'Education', mt_rand(1, $highDay));
        }
        if (mt_rand(1, 3) === 1) { // a trip every few months
            $add('expense', $this->money(150, 480), 'Weekend Trip', 'Travel', mt_rand(8, 20));
        }

        // --- Other / misc ---
        $other = ['ATM Withdrawal', 'Gift', 'Charity Donation'];
        for ($i = 0, $n = mt_rand(1, 3); $i < $n; $i++) {
            $add('expense', $this->money(10, 90), $this->pick($other), 'Other', mt_rand(1, $highDay));
        }

        // Insert everything for this month.
        foreach ($rows as $row) {
            Transaction::create([
                'user_id' => $userId,
                'category_id' => $row['category'] ? ($categories[$row['category']] ?? null) : null,
                'type' => $row['type'],
                'amount' => $row['amount'],
                'description' => $row['desc'],
                'date' => Carbon::create($year, $month, $row['day'])->toDateString(),
            ]);
        }
    }

    /** A random money amount between $min and $max, with cents (e.g. 23.47). */
    private function money(int $min, int $max): float
    {
        return mt_rand($min * 100, $max * 100) / 100;
    }

    /** Pick a random item from a list. */
    private function pick(array $items): string
    {
        return $items[array_rand($items)];
    }
}
