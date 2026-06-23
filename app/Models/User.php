<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Tymon\JWTAuth\Contracts\JWTSubject;

/**
 * The User model.
 *
 * It implements JWTSubject so that tymon/jwt-auth knows how to put this user
 * inside a JWT token and read them back out again.
 */
class User extends Authenticatable implements JWTSubject
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasFactory, Notifiable;

    /**
     * Columns that are allowed to be mass-assigned (e.g. via User::create([...])).
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'monthly_budget',
    ];

    /**
     * Columns hidden when the model is converted to JSON (so we never leak the password).
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * How certain columns should be converted when read from the database.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            // 'hashed' automatically bcrypt-hashes the password whenever it is set.
            'password' => 'hashed',
            'monthly_budget' => 'decimal:2',
        ];
    }

    /*
    |--------------------------------------------------------------------------
    | JWTSubject contract (required by tymon/jwt-auth)
    |--------------------------------------------------------------------------
    */

    /**
     * The value stored in the token's "sub" (subject) claim.
     * We use the user's primary key (id).
     */
    public function getJWTIdentifier(): mixed
    {
        return $this->getKey();
    }

    /**
     * Any extra custom data to embed inside the token.
     * We don't need any, so we return an empty array.
     *
     * @return array<string, mixed>
     */
    public function getJWTCustomClaims(): array
    {
        return [];
    }

    /*
    |--------------------------------------------------------------------------
    | Relationships
    |--------------------------------------------------------------------------
    */

    /** All transactions that belong to this user. */
    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    /** The user's own (custom) categories. */
    public function categories(): HasMany
    {
        return $this->hasMany(Category::class);
    }

    /** The user's budgets. */
    public function budgets(): HasMany
    {
        return $this->hasMany(Budget::class);
    }
}
