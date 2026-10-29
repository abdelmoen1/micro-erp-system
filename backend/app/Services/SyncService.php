<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Http\Controllers\Api\CustomerDebtController;
use App\Http\Controllers\Api\InvoiceController;
use App\Http\Middleware\EnsureIdempotency;
use App\Http\Requests\PayAllDebtsRequest;
use App\Http\Requests\StoreSaleRequest;
use App\Models\Customer;
use App\Models\Payment;
use App\Models\SyncConflict;
use App\Models\User;
use App\Support\Money;
use App\Support\OfflineSale;
use Carbon\CarbonImmutable;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use RuntimeException;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

/**
 * R2 offline sync (US-1101, D-03, doc 16 §3–4). Each queued item runs through the same
 * idempotency layer, validation and service as its online request, with the device's
 * `client_transaction_id` as the Idempotency-Key, so a sale is recorded exactly once whether its
 * online attempt arrived or not (AC-06). Business outcomes never stop the batch; a technical
 * failure does, and the device resends from that item (FIFO, BR-05).
 */
class SyncService
{
    public const MAX_BATCH = 50;

    public const STATUS_APPLIED = 'applied';

    public const STATUS_DUPLICATE = 'duplicate';

    public const STATUS_FLAGGED = 'flagged';

    public const STATUS_CONFLICT = 'conflict';

    public const STATUS_REJECTED = 'rejected_validation';

    /** The idempotency-key retention (D-04) bounds how old an offline item may be. */
    public const MAX_AGE_DAYS = 30;

    public const MAX_AHEAD_MINUTES = 10;

    /** Payments that no longer fit the customer's balance are held, not applied (D-03). */
    private const PAYMENT_CONFLICTS = ['PAYMENT_EXCEEDS_REMAINING', 'NOTHING_TO_PAY'];

    public function __construct(
        private readonly SaleService $sales,
        private readonly PaymentService $payments,
        private readonly IdempotencyService $idempotency,
        private readonly AuditService $audit,
    ) {}

    /**
     * @param  list<array<string, mixed>>  $items  validated, in the device's `seq` order
     * @return array{results: list<array<string, mixed>>, halted: ?array<string, mixed>}
     */
    public function batch(User $actor, string $deviceId, array $items): array
    {
        $results = [];

        foreach ($items as $item) {
            try {
                $results[] = $this->item($actor, $deviceId, $item);
            } catch (Throwable $e) {
                report($e);

                // Later items wait: the device resends from this one after a backoff.
                return ['results' => $results, 'halted' => [
                    'client_transaction_id' => strtolower($item['client_transaction_id']),
                    'seq' => $item['seq'] ?? null,
                ]];
            }
        }

        return ['results' => $results, 'halted' => null];
    }

    /**
     * Owner / Manager resolution of a review item (US-1106). A flagged sale is acknowledged; a
     * held payment is applied to the customer's open debts, recorded as refunded or voided; a
     * rejected item is voided. Every resolution is audited.
     */
    public function resolve(User $actor, SyncConflict $conflict, string $resolution, ?string $note): SyncConflict
    {
        return DB::transaction(function () use ($actor, $conflict, $resolution, $note) {
            $locked = SyncConflict::query()
                ->forStore($actor->store_id)
                ->whereKey($conflict->id)
                ->lockForUpdate()
                ->firstOrFail();

            if (!$locked->isOpen()) {
                throw ApiException::conflict('SYNC_CONFLICT_RESOLVED', 'تمت معالجة هذا البند مسبقًا.');
            }

            $allowed = match ($locked->kind) {
                SyncConflict::KIND_FLAGGED => [SyncConflict::RESOLUTION_ACKNOWLEDGED],
                SyncConflict::KIND_CONFLICT => [SyncConflict::RESOLUTION_APPLIED, SyncConflict::RESOLUTION_REFUNDED, SyncConflict::RESOLUTION_VOIDED],
                default => [SyncConflict::RESOLUTION_VOIDED],
            };

            if (!in_array($resolution, $allowed, true)) {
                throw ApiException::businessRule(
                    'SYNC_RESOLUTION_NOT_ALLOWED',
                    'هذه المعالجة غير متاحة لهذا النوع من البنود.',
                    ['resolution' => ['هذه المعالجة غير متاحة لهذا النوع من البنود.']],
                );
            }

            $applied = $resolution === SyncConflict::RESOLUTION_APPLIED ? $this->applyHeldPayment($actor, $locked) : null;

            $locked->update([
                'status' => SyncConflict::STATUS_RESOLVED,
                'resolution' => $resolution,
                'resolution_note' => $note,
                'resolved_by' => $actor->id,
                'resolved_at' => now(),
            ]);

            $this->audit->record('sync.conflict_resolved', $locked, [
                'client_transaction_id' => $locked->client_transaction_id,
                'kind' => $locked->kind,
                'reason' => $locked->reason,
                'resolution' => $resolution,
                'note' => $note,
                'amount' => $locked->amount === null ? null : Money::of($locked->amount),
                'payment_group_id' => $applied['payment_group_id'] ?? null,
            ], $actor);

            return $locked->load(['user', 'customer', 'resolver']);
        });
    }

    /** @return array<string, mixed> one result entry (05 §4.2) */
    private function item(User $actor, string $deviceId, array $item): array
    {
        $key = strtolower($item['client_transaction_id']);

        $held = SyncConflict::query()->forStore($actor->store_id)->where('client_transaction_id', $key)->first();

        if ($held && $held->kind !== SyncConflict::KIND_FLAGGED) {
            return $this->heldResult($held, $item);
        }

        [$methodPath, $input] = $this->target($item);

        try {
            $response = $this->idempotency->run(
                (int) $actor->store_id,
                $actor->id,
                $key,
                EnsureIdempotency::fingerprint($methodPath, $input),
                $methodPath,
                fn() => $this->apply($actor, $deviceId, $key, $item),
            );
        } catch (ValidationException $e) {
            return $this->hold($actor, $deviceId, $key, $item, SyncConflict::KIND_REJECTED, 'VALIDATION_FAILED', collect($e->errors())->flatten()->first() ?? $e->getMessage());
        } catch (AuthorizationException) {
            return $this->hold($actor, $deviceId, $key, $item, SyncConflict::KIND_REJECTED, 'FORBIDDEN', 'هذا الحساب لا يملك صلاحية هذه العملية.');
        } catch (ModelNotFoundException) {
            return $this->hold($actor, $deviceId, $key, $item, SyncConflict::KIND_REJECTED, 'NOT_FOUND', 'العميل غير موجود في متجرك.');
        } catch (ApiException $e) {
            if ($e->status >= 500) {
                throw $e;
            }

            $kind = $item['type'] === 'payment' && in_array($e->errorCode, self::PAYMENT_CONFLICTS, true)
                ? SyncConflict::KIND_CONFLICT
                : SyncConflict::KIND_REJECTED;

            return $this->hold($actor, $deviceId, $key, $item, $kind, $e->errorCode, $e->getMessage());
        }

        return $this->appliedResult($response, $item);
    }

    /**
     * The online request this item stands for: same method path and same body, so the
     * fingerprint matches an online attempt made with the same key.
     *
     * @return array{0: string, 1: array<string, mixed>}
     */
    private function target(array $item): array
    {
        $payload = $item['payload'];

        if ($item['type'] === 'sale') {
            return ['POST /api/v1/sales', $payload];
        }

        $customerId = (int) ($payload['customer_id'] ?? 0);
        unset($payload['customer_id']);

        return ["POST /api/v1/customers/{$customerId}/debts/pay-all", $payload];
    }

    private function apply(User $actor, string $deviceId, string $key, array $item): Response
    {
        $occurredAt = $this->occurredAt($item['occurred_at']);
        [, $input] = $this->target($item);

        if ($item['type'] === 'sale') {
            $validated = $this->validated(StoreSaleRequest::class, $actor, $input);
            ['invoice' => $invoice, 'warnings' => $warnings] = $this->sales->create(
                $actor,
                $validated,
                new OfflineSale($occurredAt, $deviceId, $item['charged'] ?? []),
            );

            // D-03 accept-and-flag: recorded, then listed for the manager in the same transaction.
            if ($warnings !== []) {
                $flags = array_values(array_unique(array_column($warnings, 'code')));
                SyncConflict::create($this->conflictRow($actor, $deviceId, $key, $item, SyncConflict::KIND_FLAGGED, $flags[0], null) + [
                    'invoice_id' => $invoice->id,
                    'amount' => Money::of($invoice->total_amount),
                    'flags' => $flags,
                ]);
            }

            return InvoiceController::createdResponse($invoice, $warnings);
        }

        $customer = Customer::query()->forStore($actor->store_id)->findOrFail((int) ($item['payload']['customer_id'] ?? 0));
        $validated = $this->validated(PayAllDebtsRequest::class, $actor, $input);
        $result = $this->payments->payCustomer(
            $actor,
            $customer,
            isset($validated['amount']) ? Money::of($validated['amount']) : null,
            $validated['method'],
            $occurredAt->utc()->format('Y-m-d H:i:s'),
            $validated['notes'] ?? null,
        );

        Payment::query()->where('payment_group_id', $result['payment_group_id'])->update(['synced_at' => now()]);

        return CustomerDebtController::paidResponse($result, isset($validated['amount']));
    }

    /** BR-08 with the D-04 retention as the window: from 30 days ago to a few minutes ahead. */
    private function occurredAt(string $value): CarbonImmutable
    {
        $at = CarbonImmutable::parse($value);

        if ($at->lt(now()->subDays(self::MAX_AGE_DAYS)) || $at->gt(now()->addMinutes(self::MAX_AHEAD_MINUTES))) {
            throw ApiException::businessRule(
                'OCCURRED_AT_OUT_OF_RANGE',
                'وقت العملية خارج المدة المسموحة للمزامنة. راجع ساعة الهاتف.',
                ['occurred_at' => ['وقت العملية خارج المدة المسموحة للمزامنة.']],
            );
        }

        // Stored timestamps are in the app timezone; the device sends its own offset.
        return $at->setTimezone(config('app.timezone'));
    }

    /**
     * The online FormRequest's own rules, messages and authorization, run on the queued body.
     *
     * @param  class-string<FormRequest>  $class
     */
    private function validated(string $class, User $actor, array $input): array
    {
        $form = $class::create('/', 'POST', $input);
        $form->setContainer(app())->setRedirector(app('redirect'));
        $form->setUserResolver(fn() => $actor);
        $form->validateResolved();

        return $form->validated();
    }

    /** BR-10: a refused or held item is stored for review, never discarded. */
    private function hold(User $actor, string $deviceId, string $key, array $item, string $kind, string $reason, string $message): array
    {
        try {
            $held = SyncConflict::create($this->conflictRow($actor, $deviceId, $key, $item, $kind, $reason, $message) + [
                'amount' => $item['type'] === 'payment' && isset($item['payload']['amount'])
                    ? Money::of($item['payload']['amount'])
                    : null,
            ]);
        } catch (UniqueConstraintViolationException) {
            // The same item arrived twice at once; the first stored it.
            $held = SyncConflict::query()->forStore($actor->store_id)->where('client_transaction_id', $key)->firstOrFail();
        }

        return $this->heldResult($held, $item);
    }

    private function conflictRow(User $actor, string $deviceId, string $key, array $item, string $kind, string $reason, ?string $message): array
    {
        $customerId = $item['payload']['customer_id'] ?? null;

        return [
            'store_id' => $actor->store_id,
            'device_id' => $deviceId,
            'client_transaction_id' => $key,
            'seq' => $item['seq'] ?? null,
            'type' => $item['type'],
            'kind' => $kind,
            'occurred_at' => rescue(fn() => CarbonImmutable::parse($item['occurred_at']), null, false),
            'user_id' => $actor->id,
            'customer_id' => is_numeric($customerId) && Customer::query()->forStore($actor->store_id)->withTrashed()->whereKey((int) $customerId)->exists()
                ? (int) $customerId
                : null,
            'payload' => $item,
            'reason' => $reason,
            'message' => $message,
            'status' => SyncConflict::STATUS_OPEN,
        ];
    }

    private function appliedResult(Response $response, array $item): array
    {
        if (!$response->isSuccessful()) {
            throw new RuntimeException('Unexpected sync response ' . $response->getStatusCode());
        }

        $body = json_decode($response->getContent(), true) ?? [];
        $flags = $body['flags'] ?? [];
        $replay = $response->headers->get(IdempotencyService::REPLAY_HEADER) === 'true';

        return [
            'client_transaction_id' => strtolower($item['client_transaction_id']),
            'seq' => $item['seq'] ?? null,
            'status' => $replay ? self::STATUS_DUPLICATE : ($flags !== [] ? self::STATUS_FLAGGED : self::STATUS_APPLIED),
            'server_id' => $item['type'] === 'sale' ? ($body['data']['id'] ?? null) : ($body['data']['payment_group_id'] ?? null),
            'flags' => $flags,
            'error' => null,
        ];
    }

    private function heldResult(SyncConflict $held, array $item): array
    {
        return [
            'client_transaction_id' => $held->client_transaction_id,
            'seq' => $item['seq'] ?? $held->seq,
            'status' => $held->kind === SyncConflict::KIND_CONFLICT ? self::STATUS_CONFLICT : self::STATUS_REJECTED,
            'server_id' => null,
            'flags' => [],
            'error' => ['code' => $held->reason, 'message' => $held->message],
            'conflict_id' => $held->id,
        ];
    }

    /** @return array{payment_group_id: string, total_paid: string} */
    private function applyHeldPayment(User $actor, SyncConflict $conflict): array
    {
        $payload = $conflict->payload['payload'] ?? [];
        $customer = Customer::query()->forStore($actor->store_id)->find((int) ($payload['customer_id'] ?? 0));

        if (!$customer) {
            throw ApiException::businessRule('NOTHING_TO_PAY', 'لا يوجد على هذا العميل أي مبلغ متبقي.', [
                'customer' => ['لا يوجد على هذا العميل أي مبلغ متبقي.'],
            ]);
        }

        $result = $this->payments->payCustomer(
            $actor,
            $customer,
            $conflict->amount === null ? null : Money::of($conflict->amount),
            (string) ($payload['method'] ?? 'cash'),
            $conflict->occurred_at?->utc()->format('Y-m-d H:i:s'),
            $payload['notes'] ?? null,
        );

        Payment::query()->where('payment_group_id', $result['payment_group_id'])->update(['synced_at' => now()]);

        return $result;
    }
}
