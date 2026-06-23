<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A budget is a spending limit for a given category in a given month + year.
 * Example: "In December 2026, limit Food spending to 300.00".
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('budgets', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')->constrained()->cascadeOnDelete();

            // A budget can target one category, OR be an overall budget when category_id is NULL.
            $table->foreignId('category_id')->nullable()->constrained()->nullOnDelete();

            $table->unsignedTinyInteger('month');   // 1..12
            $table->unsignedSmallInteger('year');   // e.g. 2026
            $table->decimal('limit_amount', 12, 2); // the spending cap

            $table->timestamps();

            // Prevent duplicates: one budget per user, per category, per month/year.
            // (We also use updateOrCreate() in the controller so re-posting just updates the limit.)
            $table->unique(['user_id', 'category_id', 'month', 'year']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('budgets');
    }
};
