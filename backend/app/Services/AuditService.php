<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use LogicException;

/**
 * Records critical actions. Call it inside the business transaction so the
 * audit row commits or rolls back together with the action (US-0103).
 */
class AuditService
{
    public function __construct(private readonly Request $request) {}

    /**
     * The row belongs to the actor's store, or to `$storeId` when a platform admin acts on another
     * store, so the entry sits in that store's history.
     */
    public function record(string $action, Model|string $entity, array $metadata = [], ?User $actor = null, ?int $storeId = null): AuditLog
    {
        $actor ??= Auth::user();

        if (!$actor) {
            throw new LogicException("Audit action [{$action}] requires an authenticated actor.");
        }

        [$type, $id] = $entity instanceof Model
            ? [class_basename($entity), (string) $entity->getKey()]
            : [$entity, $metadata['entity_id'] ?? null];

        return AuditLog::create([
            'store_id' => $storeId ?? $actor->store_id,
            'user_id' => $actor->id,
            'action' => $action,
            'entity_type' => $type,
            'entity_id' => $id,
            'metadata' => $metadata ?: null,
            'ip' => $this->request->ip(),
            'user_agent' => substr((string) $this->request->userAgent(), 0, 512) ?: null,
        ]);
    }
}
