<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     *
     * Run with:  php artisan db:seed
     * Or wipe + rebuild + seed with:  php artisan migrate:fresh --seed
     */
    public function run(): void
    {
        $this->call([
            // 1. The 10 shared default categories (Food, Transport, ...).
            CategorySeeder::class,
            // 2. The demo account + ~3 months of realistic data + budgets.
            //    Login:  demo@finance.com  /  password123
            DemoSeeder::class,
        ]);
    }
}
