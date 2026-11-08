<?php

namespace App\Http\Controllers\API\Mobile;

use App\Http\Controllers\Controller;
use App\Models\Invoice;
use App\Models\Payment;
use App\Models\WasteDelivery;
use App\Support\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class DashboardController extends Controller
{
    use ApiResponse;

    public function __invoke(Request $request)
    {
        $user = $request->user();

        $serviceAccounts = $user->serviceAccounts()->with('area.parent')->get();
        $serviceAccountIds = $serviceAccounts->pluck('id');

        $unpaidInvoices = Invoice::query()
            ->whereIn('service_account_id', $serviceAccountIds)
            ->where('status', 'not_paid')
            ->with('serviceAccount')
            ->orderByDesc('issued_at')
            ->get();

        $nextPickup = WasteDelivery::query()
            ->whereIn('service_account_id', $serviceAccountIds)
            ->with('serviceAccount.area.parent')
            ->whereIn('status', ['pending', 'confirmed', 'in_progress', 'scheduled', 'on_progress'])
            ->orderBy('scheduled_at')
            ->first();

        $recentDeliveries = WasteDelivery::query()
            ->whereIn('service_account_id', $serviceAccountIds)
            ->with('serviceAccount')
            ->orderByDesc('scheduled_at')
            ->limit(5)
            ->get();

        $recentPayments = Payment::query()
            ->whereHas('invoice', fn ($q) => $q->whereIn('service_account_id', $serviceAccountIds))
            ->with(['invoice.serviceAccount'])
            ->orderByDesc('created_at')
            ->limit(5)
            ->get();

        $activities = collect();

        foreach ($recentDeliveries as $delivery) {
            $activities->push([
                'type' => 'waste_delivery',
                'title' => 'Penjemputan Sampah',
                'status' => $delivery->status,
                'occurred_at' => $delivery->scheduled_at,
                'service_account' => $delivery->serviceAccount ? [
                    'id' => $delivery->serviceAccount->id,
                    'name' => $delivery->serviceAccount->name,
                    'address' => $delivery->serviceAccount->address,
                ] : null,
                'meta' => [
                    'scheduled_at' => optional($delivery->scheduled_at)->toIso8601String(),
                    'total_amount' => (float) $delivery->total_amount,
                ],
            ]);
        }

        foreach ($recentPayments as $payment) {
            $invoice = $payment->invoice;
            $activities->push([
                'type' => 'payment',
                'title' => 'Pembayaran Tagihan',
                'status' => 'paid',
                'occurred_at' => $payment->created_at,
                'service_account' => $invoice?->serviceAccount ? [
                    'id' => $invoice->serviceAccount->id,
                    'name' => $invoice->serviceAccount->name,
                    'address' => $invoice->serviceAccount->address,
                ] : null,
                'meta' => [
                    'amount' => (float) $payment->amount,
                    'payment_method' => $payment->payment_method,
                ],
            ]);
        }

        $activities = $activities
            ->sortByDesc('occurred_at')
            ->values()
            ->take(6)
            ->map(function ($activity) {
                $timestamp = $activity['occurred_at'];
                if ($timestamp instanceof Carbon) {
                    $activity['occurred_at'] = $timestamp->toIso8601String();
                } elseif ($timestamp) {
                    $activity['occurred_at'] = Carbon::parse($timestamp)->toIso8601String();
                } else {
                    $activity['occurred_at'] = null;
                }
                return $activity;
            });

        $outstandingAmount = (float) $unpaidInvoices->sum('total_amount');

        $data = [
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ],
            'summary' => [
                'service_account_total' => $serviceAccounts->count(),
                'outstanding_amount' => $outstandingAmount,
                'unpaid_invoice_count' => $unpaidInvoices->count(),
            ],
            'tagihan' => [
                'total' => $outstandingAmount,
                'items' => $unpaidInvoices->take(5)->map(function ($invoice) {
                    return [
                        'id' => $invoice->id,
                        'invoice_number' => $invoice->invoice_number,
                        'total_amount' => (float) $invoice->total_amount,
                        'issued_at' => optional($invoice->issued_at)->toIso8601String(),
                        'service_account' => $invoice->serviceAccount ? [
                            'id' => $invoice->serviceAccount->id,
                            'name' => $invoice->serviceAccount->name,
                            'address' => $invoice->serviceAccount->address,
                        ] : null,
                    ];
                })->values(),
            ],
            'next_pickup' => $nextPickup ? [
                'id' => $nextPickup->id,
                'status' => $nextPickup->status,
                'scheduled_at' => optional($nextPickup->scheduled_at)->toIso8601String(),
                'service_account' => $nextPickup->serviceAccount ? [
                    'id' => $nextPickup->serviceAccount->id,
                    'name' => $nextPickup->serviceAccount->name,
                    'address' => $nextPickup->serviceAccount->address,
                ] : null,
            ] : null,
            'recent_activities' => $activities,
        ];

        return $this->ok($data);
    }
}
