<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A monthly spending limit for a category (or an overall limit when category_id is null).
 */
class Budget extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'user_id',
        'category_id',
        'month',
        'year',
        'limit_amount',
    ];

    /**
     * @var array<string, string>
     */
    protected $casts = [
        'month'        => 'integer',
        'year'         => 'integer',
        'limit_amount' => 'decimal:2',
    ];

    /** The user this budget belongs to. */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** The category this budget caps (may be null for an overall budget). */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }
}
