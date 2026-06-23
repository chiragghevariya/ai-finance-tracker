<?php

namespace App\Services;

use OpenAI\Laravel\Facades\OpenAI;

/**
 * A thin wrapper around the OpenAI API.
 *
 * Keeping every OpenAI call in this one class means:
 *   - the controllers stay short and easy to read,
 *   - the prompts live in a single place,
 *   - and we can reuse the same calls from anywhere (jobs, commands, etc.).
 *
 * The OpenAI API key is read from config/openai.php (which reads OPENAI_API_KEY
 * from your .env file). If the key is missing the OpenAI package throws
 * OpenAI\Laravel\Exceptions\ApiKeyIsMissing, which the controllers catch.
 */
class OpenAiService
{
    /**
     * The model used for every request.
     * gpt-4o understands both text AND images (needed for receipt scanning).
     * You can change this to another vision-capable model if you like.
     */
    protected string $model = 'gpt-4o';

    /**
     * 1) RECEIPT OCR
     * Send a receipt image to GPT-4o Vision and get back structured fields.
     *
     * @param  string  $base64Image  the image encoded as base64 (WITHOUT the "data:..." prefix)
     * @param  string  $mime         the image mime type, e.g. "image/jpeg" or "image/png"
     * @return array<string, mixed>  decoded JSON: total_amount, merchant_name, date, category
     */
    public function extractReceipt(string $base64Image, string $mime = 'image/jpeg'): array
    {
        // The exact instruction we give the model. We ask for JSON so we can parse it.
        $prompt = 'Extract from this receipt: total amount, merchant name, date, '
            .'and category (Food/Transport/Shopping/Health/Entertainment/Other). '
            .'Return JSON only with these keys: '
            .'total_amount (number), merchant_name (string), date (YYYY-MM-DD), category (string).';

        $response = OpenAI::chat()->create([
            'model' => $this->model,
            // Forces the model to reply with valid JSON (supported by gpt-4o).
            'response_format' => ['type' => 'json_object'],
            'messages' => [[
                'role' => 'user',
                // For vision, the "content" is a list of parts: some text + the image.
                'content' => [
                    ['type' => 'text', 'text' => $prompt],
                    ['type' => 'image_url', 'image_url' => [
                        // The image is passed inline as a base64 "data URL".
                        'url' => "data:{$mime};base64,{$base64Image}",
                    ]],
                ],
            ]],
            'max_tokens' => 500,
        ]);

        // Pull the text the model returned and turn the JSON string into a PHP array.
        $content = $response->choices[0]->message->content ?? '{}';

        return json_decode($content, true) ?: [];
    }

    /**
     * 2) FINANCE CHAT
     * Answer a natural-language question using the user's spending summary as context.
     *
     * @param  string  $userMessage  e.g. "Where did I spend most last month?"
     * @param  string  $context      a text summary of the user's recent transactions
     * @return string                the assistant's reply
     */
    public function chat(string $userMessage, string $context): string
    {
        $systemPrompt = 'You are a personal finance assistant. Answer based on the '
            ."user's transaction data provided. Be concise and helpful.";

        $response = OpenAI::chat()->create([
            'model' => $this->model,
            'messages' => [
                // 1. Who the assistant is and how it should behave.
                ['role' => 'system', 'content' => $systemPrompt],
                // 2. The user's data, given as extra context for the assistant.
                ['role' => 'system', 'content' => "The user's recent transaction data:\n".$context],
                // 3. The user's actual question.
                ['role' => 'user', 'content' => $userMessage],
            ],
        ]);

        return $response->choices[0]->message->content ?? '';
    }

    /**
     * 3) SMART AUTO-CATEGORIZE
     * Ask the model to pick the best-matching category id for a description.
     *
     * @param  string  $description  e.g. "McDonald's lunch"
     * @param  array<int, array{id: int, name: string}>  $categories  the user's category list
     * @return int|null              the suggested category id, or null if none
     */
    public function suggestCategory(string $description, array $categories): ?int
    {
        // Build a simple "id: name" list so the model knows the available choices.
        $list = collect($categories)
            ->map(fn ($category) => "{$category['id']}: {$category['name']}")
            ->implode("\n");

        $prompt = "A user logged an expense described as: \"{$description}\".\n"
            ."Pick the single best matching category from this list:\n{$list}\n"
            .'Return JSON only in the form {"category_id": <id>}.';

        $response = OpenAI::chat()->create([
            'model' => $this->model,
            'response_format' => ['type' => 'json_object'],
            'messages' => [
                ['role' => 'user', 'content' => $prompt],
            ],
            'max_tokens' => 50,
        ]);

        $data = json_decode($response->choices[0]->message->content ?? '{}', true);

        // Return the id as an integer, or null if the model didn't give one.
        return isset($data['category_id']) ? (int) $data['category_id'] : null;
    }
}
