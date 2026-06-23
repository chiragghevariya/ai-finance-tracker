<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A single income or expense entry.
 */
class Transaction extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'user_id',
        'category_id',
        'type',          // 'income' or 'expense'
        'amount',
        'description',
        'note',
        'date',
        'receipt_image',
    ];

    /**
     * Cast columns to handy PHP types:
     *  - amount as a 2-decimal string (precise money, never a lossy float)
     *  - date as a Carbon date object
     *
     * @var array<string, string>
     */
    protected $casts = [
        'amount' => 'decimal:2',
        'date'   => 'date',
    ];

    /** The user this transaction belongs to. */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** The category this transaction is filed under (may be null). */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }
}
