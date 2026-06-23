<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use OpenAI\Laravel\Facades\OpenAI;
use OpenAI\Responses\Chat\CreateResponse;
use Tests\TestCase;

/**
 * Tests the three Phase 2 AI endpoints WITHOUT calling the real OpenAI API.
 *
 * OpenAI::fake([...]) swaps the OpenAI client for a fake that returns the
 * responses we queue. That means:
 *   - no network calls are made,
 *   - no real API key is needed,
 *   - and we can prove our controllers build the request and parse the
 *     response correctly.
 */
class AiEndpointsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Pretend a key is configured so the controllers' "key missing" guard passes.
        // (The faked client below means nothing is actually sent to OpenAI.)
        config(['openai.api_key' => 'sk-test-fake-key']);
    }

    public function test_receipt_scan_returns_parsed_fields(): void
    {
        $user = User::factory()->create();
        $food = Category::create([
            'name' => 'Food', 'icon' => '🍔', 'color' => '#FF7043', 'is_default' => true,
        ]);

        // Queue the JSON we want the fake "model" to return.
        OpenAI::fake([
            CreateResponse::fake([
                'choices' => [[
                    'message' => ['content' => json_encode([
                        'total_amount'  => 23.45,
                        'merchant_name' => "McDonald's",
                        'date'          => '2026-06-01',
                        'category'      => 'Food',
                    ])],
                ]],
            ]),
        ]);

        $response = $this->actingAs($user, 'api')->postJson('/api/receipt/scan', [
            'image_base64' => base64_encode('pretend-image-bytes'),
        ]);

        $response->assertOk()->assertJson([
            'merchant_name'         => "McDonald's",
            'total_amount'          => 23.45,
            'date'                  => '2026-06-01',
            'category'              => 'Food',
            'suggested_category_id' => $food->id, // matched by name to the user's category
        ]);
    }

    public function test_ai_chat_returns_reply(): void
    {
        $user = User::factory()->create();
        Transaction::create([
            'user_id'     => $user->id,
            'type'        => 'expense',
            'amount'      => 50,
            'description' => 'Groceries',
            'date'        => now()->toDateString(),
        ]);

        OpenAI::fake([
            CreateResponse::fake([
                'choices' => [[
                    'message' => ['content' => 'You spent most on groceries last month.'],
                ]],
            ]),
        ]);

        $response = $this->actingAs($user, 'api')->postJson('/api/ai/chat', [
            'message' => 'Where did I spend most last month?',
        ]);

        $response->assertOk()->assertJson([
            'reply' => 'You spent most on groceries last month.',
        ]);
    }

    public function test_auto_categorize_returns_suggested_category_id(): void
    {
        $user = User::factory()->create();
        $food = Category::create([
            'name' => 'Food', 'icon' => '🍔', 'color' => '#FF7043', 'is_default' => true,
        ]);

        OpenAI::fake([
            CreateResponse::fake([
                'choices' => [[
                    'message' => ['content' => json_encode(['category_id' => $food->id])],
                ]],
            ]),
        ]);

        $response = $this->actingAs($user, 'api')->postJson('/api/transactions/auto-categorize', [
            'description' => "McDonald's lunch",
        ]);

        $response->assertOk()->assertJson([
            'suggested_category_id' => $food->id,
        ]);
    }

    public function test_ai_endpoints_require_authentication(): void
    {
        // Without a token, every AI endpoint must return 401 Unauthenticated.
        $this->postJson('/api/ai/chat', ['message' => 'hi'])->assertUnauthorized();
        $this->postJson('/api/receipt/scan', ['image_base64' => 'x'])->assertUnauthorized();
        $this->postJson('/api/transactions/auto-categorize', ['description' => 'x'])->assertUnauthorized();
    }

    public function test_chat_validates_message_is_required(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user, 'api')
            ->postJson('/api/ai/chat', [])      // no "message"
            ->assertStatus(422);
    }
}
