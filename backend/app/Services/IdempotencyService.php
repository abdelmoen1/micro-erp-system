<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\IdempotencyKey;
use Closure;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

/**
 * Executes a financial request at most once per (store, Idempotency-Key).
 *
 * The business effect and the key row are committed in the same database
 * transaction, so either both exist or neither does (US-0101, D-04).
 */
class IdempotencyService
{
    public const REPLAY_HEADER = 'Idempotent-Replay';

    /**
     * @param  Closure(): Response  $action
     */
    public function run(int $storeId, ?int $userId, string $key, string $requestHash, string $methodPath, Closure $action): Response
    {
        if ($existing = $this->find($storeId, $key)) {
            return $this->replay($existing, $requestHash);
        }

        DB::beginTransaction();

        try {
            $response = $action();

            if (!$response->isSuccessful()) {
                DB::rollBack();

                // A concurrent request with the same key may have committed
                // while this one was waiting on a row lock.
                $winner = $this->find($storeId, $key);

                return $winner ? $this->replay($winner, $requestHash) : $response;
            }

            IdempotencyKey::create([
                'store_id' => $storeId,
                'user_id' => $userId,
                'key' => $key,
                'request_hash' => $requestHash,
                'method_path' => $methodPath,
                'response_status' => $response->getStatusCode(),
                'response_body' => $response->getContent(),
            ]);

            DB::commit();

            return $response;
        } catch (UniqueConstraintViolationException $e) {
            DB::rollBack();

            $winner = $this->find($storeId, $key);

            if (!$winner) {
                throw $e;
            }

            return $this->replay($winner, $requestHash);
        } catch (Throwable $e) {
            DB::rollBack();

            throw $e;
        }
    }

    protected function find(int $storeId, string $key): ?IdempotencyKey
    {
        return IdempotencyKey::query()
            ->where('store_id', $storeId)
            ->where('key', $key)
            ->first();
    }

    private function replay(IdempotencyKey $stored, string $requestHash): Response
    {
        if (!hash_equals($stored->request_hash, $requestHash)) {
            throw new ApiException(
                409,
                'IDEMPOTENCY_KEY_REUSED',
                'تم استخدام مفتاح منع التكرار مسبقاً لطلب مختلف.',
            );
        }

        return response($stored->response_body, $stored->response_status, [
            'Content-Type' => 'application/json',
            self::REPLAY_HEADER => 'true',
        ]);
    }

    public function prune(int $days): int
    {
        return IdempotencyKey::query()
            ->where('created_at', '<', now()->subDays($days))
            ->delete();
    }
}
