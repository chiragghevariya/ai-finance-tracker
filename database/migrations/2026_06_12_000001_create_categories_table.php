<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Categories group transactions (Food, Transport, ...).
 *
 * There are two kinds of category:
 *   1. Default categories  -> user_id is NULL, is_default = true.
 *      These are shared by everyone and are created by CategorySeeder.
 *   2. User categories      -> user_id is set, is_default = false.
 *      A user can create their own custom categories later.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('categories', function (Blueprint $table) {
            $table->id();

            // Owner of the category.
            // NULL means it is a global/default category that belongs to nobody in particular.
            // If the owning user is deleted, delete their custom categories too.
            $table->foreignId('user_id')->nullable()->constrained()->cascadeOnDelete();

            $table->string('name');                          // e.g. "Food"
            $table->string('color', 7)->default('#9E9E9E');  // hex colour, e.g. "#FF5733"
            $table->string('icon', 16)->default('💼');       // emoji icon, e.g. "🍔"
            $table->boolean('is_default')->default(false);   // true for the 10 seeded categories

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('categories');
    }
};
