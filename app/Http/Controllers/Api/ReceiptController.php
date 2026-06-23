<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Services\OpenAiService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use OpenAI\Laravel\Exceptions\ApiKeyIsMissing;

/**
 * Handles receipt scanning (OCR) using OpenAI's GPT-4o Vision model.
 */
class ReceiptController extends Controller
{
    /**
     * POST /api/receipt/scan
     *
     * Accepts a receipt image as EITHER:
     *   - an uploaded file  -> form field "image", OR
     *   - a base64 string   -> field "image_base64"
     *
     * Sends it to OpenAI Vision and returns the extracted fields
     * (merchant, total, date, category) as JSON for the Flutter app.
     */
    public function scan(Request $request, OpenAiService $ai): JsonResponse
    {
        // Both inputs are optional individually, but we need at least one (checked below).
        $request->validate([
            'image'        => ['nullable', 'image', 'max:10240'], // uploaded file, up to ~10 MB
            'image_base64' => ['nullable', 'string'],             // or a base64 string
        ]);

        // Figure out the base64 data + mime type from whichever input was provided.
        if ($request->hasFile('image')) {
            $file   = $request->file('image');
            $base64 = base64_encode(file_get_contents($file->getRealPath()));
            $mime   = $file->getMimeType() ?: 'image/jpeg';
        } elseif ($request->filled('image_base64')) {
            $base64 = $request->input('image_base64');
            // If the client sent a full data URL ("data:image/png;base64,AAAA..."),
            // strip the prefix and keep only the base64 part after the comma.
            if (str_contains($base64, ',')) {
                $base64 = substr($base64, strpos($base64, ',') + 1);
            }
            $mime = 'image/jpeg';
        } else {
            // Neither an image file nor a base64 string was sent.
            return response()->json([
                'message' => 'Please provide a receipt image (field "image") or "image_base64".',
            ], 422);
        }

        // Make sure OpenAI is configured before we try to use it.
        if (blank(config('openai.api_key'))) {
            return response()->json([
                'message' => 'OpenAI API key is not configured. Add OPENAI_API_KEY to your .env file.',
            ], 503);
        }

        // Call OpenAI Vision. Wrap it so a failure returns a clean error, not a 500 page.
        try {
            $data = $ai->extractReceipt($base64, $mime);
        } catch (ApiKeyIsMissing $e) {
            return response()->json(['message' => 'OpenAI API key is not configured.'], 503);
        } catch (\Throwable $e) {
            report($e); // log the real error for debugging
            return response()->json([
                'message' => 'Could not read the receipt. Please try again.',
                'error'   => config('app.debug') ? $e->getMessage() : null,
            ], 502);
        }

        // Nice-to-have: if the category name the AI returned matches one of the
        // user's categories, include its id so the app can pre-select it.
        $suggestedCategoryId = null;
        if (! empty($data['category'])) {
            $suggestedCategoryId = Category::query()
                ->where(function ($query) {
                    $query->whereNull('user_id')->orWhere('user_id', auth('api')->id());
                })
                ->whereRaw('LOWER(name) = ?', [strtolower($data['category'])])
                ->value('id');
        }

        // Return a tidy, predictable shape to the Flutter app.
        return response()->json([
            'merchant_name'         => $data['merchant_name'] ?? null,
            'total_amount'          => $data['total_amount'] ?? null,
            'date'                  => $data['date'] ?? null,
            'category'              => $data['category'] ?? null,
            'suggested_category_id' => $suggestedCategoryId,
            'raw'                   => $data, // the full parsed JSON, handy while developing
        ]);
    }
}
