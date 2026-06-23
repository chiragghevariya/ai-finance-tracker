<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A spending/income category, e.g. "Food 🍔".
 *
 * Default categories have user_id = null and is_default = true (created by the seeder).
 * Custom categories belong to a single user.
 */
class Category extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'user_id',
        'name',
        'color',
        'icon',
        'is_default',
    ];

    /**
     * @var array<string, string>
     */
    protected $casts = [
        'is_default' => 'boolean',
    ];

    /** The user that owns this category (null for default categories). */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** All transactions filed under this category. */
    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }
}
