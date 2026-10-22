<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Http\Requests\ProductMessages;
use App\Models\Product;
use App\Models\User;
use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

/**
 * US-0408: onboard a pilot shop from a CSV file. Every row is validated with the same rules as
 * POST /products (US-0401, CR-13); only a file without a single error is imported, in one
 * transaction, so a shop never ends up with half a catalogue. Each product gets its `opening`
 * stock movement through ProductService.
 */
class ProductImportService
{
    public const COLUMNS = ['name', 'barcode', 'unit', 'selling_price', 'cost_price', 'current_stock', 'minimum_stock'];

    public const MAX_ROWS = 2000;

    public function __construct(
        private readonly ProductService $products,
        private readonly AuditService $audit,
    ) {}

    /**
     * @return array{rows: int, pieces: int, kg: int, imported: int}
     */
    public function import(User $actor, UploadedFile $file, bool $dryRun): array
    {
        $rows = $this->read($file);
        $errors = $this->validate($actor, $rows);

        if ($errors !== []) {
            $count = count(array_unique(array_column($errors, 'row')));
            $message = "{$count} من " . count($rows) . ' صفًا فيها أخطاء. لم يُستورد شيء.';

            throw ApiException::businessRule('IMPORT_INVALID', $message, ['file' => [$message]], [
                'rows' => count($rows),
                'invalid_rows' => $count,
                'errors' => array_slice($errors, 0, 200),
            ]);
        }

        $kg = count(array_filter($rows, fn($row) => ($row['data']['unit'] ?? Quantity::UNIT_PIECE) === Quantity::UNIT_KG));
        $summary = ['rows' => count($rows), 'pieces' => count($rows) - $kg, 'kg' => $kg, 'imported' => 0];

        if ($dryRun) {
            return $summary;
        }

        DB::transaction(function () use ($actor, $rows) {
            foreach ($rows as $row) {
                $this->products->create($actor, $row['data']);
            }
            $this->audit->record('products.imported', 'ProductImport', [
                'entity_id' => (string) $actor->store_id,
                'count' => count($rows),
            ], $actor);
        });

        return ['imported' => count($rows)] + $summary;
    }

    /** @return list<array{line: int, data: array<string, mixed>}> */
    private function read(UploadedFile $file): array
    {
        $handle = fopen($file->getRealPath(), 'r');
        $header = fgetcsv($handle);

        if ($header === false || $header === [null]) {
            throw $this->fileError('الملف فارغ.');
        }

        // Excel adds a UTF-8 byte-order mark to the first cell.
        $header = array_map(fn($h) => strtolower(trim(preg_replace('/^\xEF\xBB\xBF/', '', (string) $h))), $header);
        $missing = array_diff(['name', 'selling_price', 'current_stock'], $header);

        if ($missing !== []) {
            throw $this->fileError('أعمدة ناقصة في الصف الأول: ' . implode(', ', $missing));
        }

        $rows = [];
        $line = 1;

        while (($cells = fgetcsv($handle)) !== false) {
            $line++;
            if ($cells === [null] || implode('', array_map('trim', array_map('strval', $cells))) === '') {
                continue;
            }
            if (count($rows) >= self::MAX_ROWS) {
                throw $this->fileError('الحد الأقصى ' . self::MAX_ROWS . ' صف في الملف الواحد.');
            }

            $data = [];
            foreach (self::COLUMNS as $column) {
                $index = array_search($column, $header, true);
                $value = $index === false ? null : trim((string) ($cells[$index] ?? ''));
                $data[$column] = $value === '' ? null : $value;
            }
            $data['unit'] ??= Quantity::UNIT_PIECE;
            $data['unit'] = strtolower($data['unit']);
            $rows[] = ['line' => $line, 'data' => array_filter($data, fn($v) => $v !== null)];
        }

        fclose($handle);

        if ($rows === []) {
            throw $this->fileError('لا صفوف بيانات في الملف.');
        }

        return $rows;
    }

    /** @return list<array{row: int, column: string, message: string}> */
    private function validate(User $actor, array $rows): array
    {
        $errors = [];
        $seen = [];
        $existing = Product::query()
            ->forStore($actor->store_id)
            ->whereIn('barcode', array_filter(array_map(fn($row) => $row['data']['barcode'] ?? null, $rows)))
            ->pluck('name', 'barcode');

        foreach ($rows as $row) {
            $data = $row['data'];
            $unit = in_array($data['unit'] ?? null, Quantity::UNITS, true) ? $data['unit'] : Quantity::UNIT_PIECE;

            $validator = Validator::make($data, [
                'name' => ['required', 'string', 'max:255'],
                'barcode' => ['nullable', 'string', 'max:64'],
                'unit' => ['required', Rule::in(Quantity::UNITS)],
                'selling_price' => ['required', ...Money::inputRules()],
                'cost_price' => ['nullable', 'numeric', 'decimal:0,2', 'min:0', 'max:' . Money::MAX],
                'current_stock' => ['required', ...ProductMessages::stockRules($unit)],
                'minimum_stock' => ['nullable', ...ProductMessages::stockRules($unit)],
            ], ProductMessages::all() + ['unit.in' => 'الوحدة يجب أن تكون piece أو kg.']);

            foreach ($validator->errors()->messages() as $column => $messages) {
                $errors[] = ['row' => $row['line'], 'column' => $column, 'message' => $messages[0]];
            }

            $barcode = $data['barcode'] ?? null;
            if ($barcode !== null) {
                if (isset($existing[$barcode])) {
                    $errors[] = ['row' => $row['line'], 'column' => 'barcode', 'message' => "الباركود {$barcode} موجود في متجرك ({$existing[$barcode]})."];
                } elseif (isset($seen[$barcode])) {
                    $errors[] = ['row' => $row['line'], 'column' => 'barcode', 'message' => "الباركود {$barcode} مكرر في الصف {$seen[$barcode]}."];
                }
                $seen[$barcode] ??= $row['line'];
            }
        }

        return $errors;
    }

    private function fileError(string $message): ApiException
    {
        return ApiException::businessRule('IMPORT_INVALID', $message, ['file' => [$message]], ['rows' => 0, 'invalid_rows' => 0, 'errors' => []]);
    }
}
