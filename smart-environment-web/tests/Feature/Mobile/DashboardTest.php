<?php

namespace Tests\Feature\Mobile;

use App\Models\Area;
use App\Models\Invoice;
use App\Models\Payment;
use App\Models\Schedule;
use App\Models\ServiceAccount;
use App\Models\User;
use App\Models\WasteDelivery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DashboardTest extends TestCase
{
    use RefreshDatabase;

    protected function authenticate(User $user): void
    {
        Sanctum::actingAs($user, [], 'api');
    }

    protected function createServiceAccount(User $user): ServiceAccount
    {
        $district = Area::create([
            'name' => 'Kecamatan Dashboard',
            'level' => 'kecamatan',
        ]);

        $area = Area::create([
            'name' => 'Kelurahan Dashboard',
            'level' => 'kelurahan',
            'parent_id' => $district->id,
        ]);

        Schedule::create([
            'area_id' => $area->id,
            'day_of_week' => 'monday',
            'pickup_time' => Carbon::createFromTime(8, 0),
        ]);

        return ServiceAccount::create([
            'user_id' => $user->id,
            'area_id' => $area->id,
            'name' => 'Rumah Dashboard',
            'contact_phone' => '081111111',
            'address' => 'Jl. Dashboard No. 1',
            'latitude' => -6.25,
            'longitude' => 106.75,
            'note' => null,
            'status' => 'active',
        ]);
    }

    public function test_dashboard_returns_expected_summary(): void
    {
        $user = User::factory()->create();
        $serviceAccount = $this->createServiceAccount($user);
        $this->authenticate($user);

        $deliveryUpcoming = WasteDelivery::create([
            'service_account_id' => $serviceAccount->id,
            'status' => 'pending',
            'scheduled_at' => Carbon::now()->addDay(),
            'note' => 'Penjemputan mingguan',
            'total_amount' => 125000,
        ]);

        $deliveryPast = WasteDelivery::create([
            'service_account_id' => $serviceAccount->id,
            'status' => 'collected',
            'scheduled_at' => Carbon::now()->subDays(3),
            'note' => 'Sudah diambil',
            'total_amount' => 100000,
        ]);

        $invoiceUnpaid = Invoice::create([
            'waste_delivery_id' => $deliveryUpcoming->id,
            'service_account_id' => $serviceAccount->id,
            'invoice_number' => 'INV-UNPAID-001',
            'va_number' => '1234567890',
            'va_expiry_at' => Carbon::now()->addDays(3),
            'total_amount' => 150000,
            'status' => 'not_paid',
            'issued_at' => Carbon::now()->subDay(),
            'paid_at' => null,
        ]);

        $invoicePaid = Invoice::create([
            'waste_delivery_id' => $deliveryPast->id,
            'service_account_id' => $serviceAccount->id,
            'invoice_number' => 'INV-PAID-002',
            'va_number' => '0987654321',
            'va_expiry_at' => Carbon::now()->subDays(2),
            'total_amount' => 90000,
            'status' => 'paid',
            'issued_at' => Carbon::now()->subDays(4),
            'paid_at' => Carbon::now()->subDays(2),
        ]);

        Payment::create([
            'invoice_id' => $invoicePaid->id,
            'amount' => 90000,
            'payment_method' => 'transfer',
            'provider_transaction_id' => 'trx-001',
        ]);

        $response = $this->getJson('/api/v1/mobile/dashboard');

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.summary.service_account_total', 1)
            ->assertJsonPath('data.summary.unpaid_invoice_count', 1)
            ->assertJsonPath('data.tagihan.total', 150000)
            ->assertJsonPath('data.next_pickup.service_account.id', $serviceAccount->id)
            ->assertJsonPath('data.recent_activities.0.type', 'waste_delivery')
            ->assertJsonPath('data.tagihan.items.0.service_account.id', $serviceAccount->id);
    }
}
