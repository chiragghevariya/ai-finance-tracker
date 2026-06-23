<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rules\Password;

/**
 * Handles user registration and JWT-based authentication.
 *
 * Flow:
 *   1. register / login  -> returns a JWT "access_token".
 *   2. The client stores that token and sends it on every future request as:
 *        Authorization: Bearer <access_token>
 *   3. me / logout       -> require a valid token (protected by the "auth:api" middleware).
 */
class AuthController extends Controller
{
    /**
     * POST /api/register
     * Create a new user account and immediately log them in (return a token).
     */
    public function register(Request $request): JsonResponse
    {
        // 1. Validate the incoming data. Laravel throws a 422 JSON response on failure.
        $data = $request->validate([
            'name'           => ['required', 'string', 'max:255'],
            'email'          => ['required', 'email', 'max:255', 'unique:users,email'],
            // "confirmed" requires a matching "password_confirmation" field.
            'password'       => ['required', 'confirmed', Password::min(6)],
            'monthly_budget' => ['nullable', 'numeric', 'min:0'], // optional overall budget
        ]);

        // 2. Create the user. The password is automatically hashed by the model's
        //    'password' => 'hashed' cast, so we never store it in plain text.
        $user = User::create($data);

        // 3. Generate a JWT for the brand-new user and return it.
        $token = auth('api')->login($user);

        return $this->respondWithToken($token, $user, 201);
    }

    /**
     * POST /api/login
     * Check the email + password and, if correct, return a JWT.
     */
    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email'    => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        // attempt() verifies the credentials and returns a token, or false if they're wrong.
        $token = auth('api')->attempt($credentials);

        if (! $token) {
            return response()->json(['message' => 'Invalid email or password.'], 401);
        }

        return $this->respondWithToken($token, auth('api')->user());
    }

    /**
     * GET /api/me
     * Return the currently authenticated user (requires a valid token).
     */
    public function me(): JsonResponse
    {
        return response()->json(auth('api')->user());
    }

    /**
     * POST /api/logout
     * Invalidate the current token so it can no longer be used.
     */
    public function logout(): JsonResponse
    {
        auth('api')->logout();

        return response()->json(['message' => 'Successfully logged out.']);
    }

    /**
     * Build a consistent JSON response containing the token and the user.
     *
     * @param  string  $token  the JWT string
     */
    protected function respondWithToken(string $token, User $user, int $status = 200): JsonResponse
    {
        return response()->json([
            'access_token' => $token,
            'token_type'   => 'bearer',
            // How long (in seconds) the token stays valid. getTTL() is in minutes.
            'expires_in'   => auth('api')->factory()->getTTL() * 60,
            'user'         => $user,
        ], $status);
    }
}
