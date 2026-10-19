<?php

namespace Tests\Support;

use App\Models\Customer;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\Store;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

trait BuildsShopData
{
    protected function makeStore(string $name = 'Main', array $attributes = []): Store
    {
        return Store::create(['name' => $name] + $attributes);
    }

    protected function makeUser(Store $store, string $role = 'owner', array $attributes = []): User
    {
        return User::factory()->create([
            'store_id' => $store->id,
            'role' => $role,
            'password' => Hash::make('password'),
        ] + $attributes);
    }

    protected function makeCustomer(Store $store, ?string $phone = null): Customer
    {
        static $sequence = 0;
        $sequence++;

        return Customer::create([
            'store_id' => $store->id,
            'name' => 'Customer ' . $sequence,
            'phone' => $phone ?? sprintf('059%07d', $sequence),
        ]);
    }

    protected function makeCreditInvoice(Store $store, Customer $customer, string $total = '100.00'): Invoice
    {
        $invoice = Invoice::create([
            'store_id' => $store->id,
            'customer_id' => $customer->id,
            'total_amount' => $total,
            'has_debt' => true,
            'payment_method' => null,
            'source' => 'sale',
        ]);
        $invoice->items()->create(['item_name' => 'Item', 'quantity' => 1, 'unit_price' => $total, 'total' => $total]);
        Debt::create([
            'store_id' => $store->id,
            'invoice_id' => $invoice->id,
            'amount' => $total,
            'remaining_amount' => $total,
            'status' => 'unpaid',
        ]);

        return $invoice->fresh('debt');
    }

    protected function makeProduct(Store $store, array $attributes = []): Product
    {
        static $sequence = 0;
        $sequence++;

        return Product::create($attributes + [
            'store_id' => $store->id,
            'name' => 'Product ' . $sequence,
            'barcode' => sprintf('729%010d', $sequence),
            'selling_price' => '10.00',
            'current_stock' => 10,
            'minimum_stock' => 5,
            'status' => Product::STATUS_ACTIVE,
        ]);
    }
}
