<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A transaction is a single piece of money movement:
 * either INCOME (money in) or EXPENSE (money out).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('transactions', function (Blueprint $table) {
            $table->id();

            // Every transaction belongs to a user. Delete the user -> delete their transactions.
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();

            // The category is optional. If a category is deleted we keep the transaction
            // but set category_id to NULL, so we never lose the user's financial history.
            $table->foreignId('category_id')->nullable()->constrained()->nullOnDelete();

            // Direction of the money. We store the amount as a positive number and use
            // this flag to know whether it adds to or subtracts from the balance.
            $table->enum('type', ['income', 'expense']);

            // Money value. decimal(12,2) safely holds up to 9,999,999,999.99 with 2 decimals.
            $table->decimal('amount', 12, 2);

            $table->string('description');                 // short title, e.g. "Lunch"
            $table->text('note')->nullable();              // optional longer note
            $table->date('date');                          // the day the money moved
            $table->string('receipt_image')->nullable();   // stored path to an uploaded receipt photo

            $table->timestamps();

            // We very often ask "this user's transactions within this month",
            // so index user_id + date together to keep those queries fast.
            $table->index(['user_id', 'date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('transactions');
    }
};
