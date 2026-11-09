<?php

namespace App\Http\Controllers\API\Mobile\Resident;

use App\Http\Controllers\Controller;
use App\Models\Invoice;
use App\Services\VirtualAccountService;
use App\Support\ApiResponse;
use Illuminate\Http\Request;

class InvoiceController extends Controller
{
    use ApiResponse;

    protected VirtualAccountService $vaService;

    public function __construct(VirtualAccountService $vaService)
    {
        $this->vaService = $vaService;
    }

    /**
     * Get list of invoices for current user
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $serviceAccountIds = $user->serviceAccounts()->pluck('id');

        $query = Invoice::query()
            ->whereIn('service_account_id', $serviceAccountIds)
            ->with(['serviceAccount', 'wasteDelivery', 'payments']);

        // Filter by status
        if ($status = $request->input('status')) {
            $query->where('status', $status);
        }

        // Filter by service account
        if ($serviceAccountId = $request->input('service_account_id')) {
            $query->where('service_account_id', $serviceAccountId);
        }

        // Filter by date range
        if ($startDate = $request->input('start_date')) {
            $query->whereDate('issued_at', '>=', $startDate);
        }

        if ($endDate = $request->input('end_date')) {
            $query->whereDate('issued_at', '<=', $endDate);
        }

        $perPage = $request->input('per_page', 15);
        $invoices = $query->orderByDesc('issued_at')->paginate($perPage);

        $data = $invoices->getCollection()->map(function ($invoice) {
            $bank = $invoice->va_number ? $this->vaService->getBankFromVA($invoice->va_number) : null;
            $isExpired = $invoice->va_expiry_at && $invoice->va_expiry_at->isPast() && $invoice->status !== 'paid';
            
            return [
                'id' => $invoice->id,
                'invoice_number' => $invoice->invoice_number,
                'va_number' => $invoice->va_number,
                'va_number_formatted' => $invoice->va_number ? $this->vaService->formatVADisplay($invoice->va_number) : null,
                'va_bank' => $bank ? strtoupper($bank) : null,
                'total_amount' => (float) $invoice->total_amount,
                'status' => $invoice->status,
                'issued_at' => $invoice->issued_at?->toIso8601String(),
                'paid_at' => $invoice->paid_at?->toIso8601String(),
                'va_expiry_at' => $invoice->va_expiry_at?->toIso8601String(),
                'service_account' => [
                    'id' => $invoice->serviceAccount->id,
                    'name' => $invoice->serviceAccount->name,
                    'address' => $invoice->serviceAccount->address,
                ],
                'payment_count' => $invoice->payments->count(),
                'is_expired' => $isExpired,
            ];
        });

        return $this->ok([
            'invoices' => $data,
            'meta' => [
                'current_page' => $invoices->currentPage(),
                'last_page' => $invoices->lastPage(),
                'per_page' => $invoices->perPage(),
                'total' => $invoices->total(),
            ],
        ]);
    }

    /**
     * Get single invoice detail
     */
    public function show(Request $request, string $id)
    {
        $user = $request->user();

        $serviceAccountIds = $user->serviceAccounts()->pluck('id');

        $invoice = Invoice::with([
            'serviceAccount.area',
            'wasteDelivery.wasteDeliveryItems.waste',
            'wasteDelivery.wasteDeliveryItems.pocketSize',
            'payments'
        ])
        ->whereIn('service_account_id', $serviceAccountIds)
        ->find($id);

        if (!$invoice) {
            return $this->error('Invoice not found.', 404);
        }

        $bank = $invoice->va_number ? $this->vaService->getBankFromVA($invoice->va_number) : null;
        $isExpired = $invoice->va_expiry_at && $invoice->va_expiry_at->isPast() && $invoice->status !== 'paid';

        return $this->ok([
            'invoice' => [
                'id' => $invoice->id,
                'invoice_number' => $invoice->invoice_number,
                'va_number' => $invoice->va_number,
                'va_number_formatted' => $invoice->va_number ? $this->vaService->formatVADisplay($invoice->va_number) : null,
                'va_bank' => $bank ? strtoupper($bank) : null,
                'total_amount' => (float) $invoice->total_amount,
                'status' => $invoice->status,
                'issued_at' => $invoice->issued_at?->toIso8601String(),
                'paid_at' => $invoice->paid_at?->toIso8601String(),
                'va_expiry_at' => $invoice->va_expiry_at?->toIso8601String(),
                'is_expired' => $isExpired,
                'service_account' => [
                    'id' => $invoice->serviceAccount->id,
                    'name' => $invoice->serviceAccount->name,
                    'address' => $invoice->serviceAccount->address,
                    'contact_phone' => $invoice->serviceAccount->contact_phone,
                    'area' => $invoice->serviceAccount->area ? [
                        'id' => $invoice->serviceAccount->area->id,
                        'name' => $invoice->serviceAccount->area->name,
                    ] : null,
                ],
                'waste_delivery' => $invoice->wasteDelivery ? [
                    'id' => $invoice->wasteDelivery->id,
                    'status' => $invoice->wasteDelivery->status,
                    'scheduled_at' => $invoice->wasteDelivery->scheduled_at?->toIso8601String(),
                    'items' => $invoice->wasteDelivery->wasteDeliveryItems->map(function ($item) {
                        return [
                            'id' => $item->id,
                            'quantity' => $item->quantity,
                            'unit_price' => (float) $item->unit_price,
                            'total_price' => (float) $item->total_price,
                            'waste' => [
                                'id' => $item->waste->id,
                                'category' => $item->waste->category,
                                'code' => $item->waste->code,
                            ],
                            'pocket_size' => [
                                'id' => $item->pocketSize->id,
                                'name' => $item->pocketSize->name,
                            ],
                        ];
                    })->values(),
                ] : null,
                'payments' => $invoice->payments->map(function ($payment) {
                    return [
                        'id' => $payment->id,
                        'amount' => (float) $payment->amount,
                        'payment_method' => $payment->payment_method,
                        'provider_transaction_id' => $payment->provider_transaction_id,
                        'created_at' => $payment->created_at?->toIso8601String(),
                    ];
                })->values(),
            ],
        ]);
    }

    /**
     * Get unpaid invoices
     */
    public function unpaid(Request $request)
    {
        $user = $request->user();

        $serviceAccountIds = $user->serviceAccounts()->pluck('id');

        $invoices = Invoice::query()
            ->whereIn('service_account_id', $serviceAccountIds)
            ->where('status', 'not_paid')
            ->with(['serviceAccount'])
            ->orderByDesc('issued_at')
            ->get()
            ->map(function ($invoice) {
                $bank = $invoice->va_number ? $this->vaService->getBankFromVA($invoice->va_number) : null;
                $isExpired = $invoice->va_expiry_at && $invoice->va_expiry_at->isPast();
                
                return [
                    'id' => $invoice->id,
                    'invoice_number' => $invoice->invoice_number,
                    'va_number' => $invoice->va_number,
                    'va_number_formatted' => $invoice->va_number ? $this->vaService->formatVADisplay($invoice->va_number) : null,
                    'va_bank' => $bank ? strtoupper($bank) : null,
                    'total_amount' => (float) $invoice->total_amount,
                    'issued_at' => $invoice->issued_at?->toIso8601String(),
                    'va_expiry_at' => $invoice->va_expiry_at?->toIso8601String(),
                    'is_expired' => $isExpired,
                    'service_account' => [
                        'id' => $invoice->serviceAccount->id,
                        'name' => $invoice->serviceAccount->name,
                        'address' => $invoice->serviceAccount->address,
                    ],
                ];
            });

        $totalAmount = $invoices->sum('total_amount');

        return $this->ok([
            'unpaid_invoices' => $invoices,
            'total_amount' => $totalAmount,
            'count' => $invoices->count(),
        ]);
    }

    /**
     * Get invoice statistics
     */
    public function statistics(Request $request)
    {
        $user = $request->user();

        $serviceAccountIds = $user->serviceAccounts()->pluck('id');

        $total = Invoice::whereIn('service_account_id', $serviceAccountIds)->count();
        $paid = Invoice::whereIn('service_account_id', $serviceAccountIds)->where('status', 'paid')->count();
        $unpaid = Invoice::whereIn('service_account_id', $serviceAccountIds)->where('status', 'not_paid')->count();

        $totalAmount = Invoice::whereIn('service_account_id', $serviceAccountIds)->sum('total_amount');
        $paidAmount = Invoice::whereIn('service_account_id', $serviceAccountIds)
            ->where('status', 'paid')
            ->sum('total_amount');
        $unpaidAmount = Invoice::whereIn('service_account_id', $serviceAccountIds)
            ->where('status', 'not_paid')
            ->sum('total_amount');

        return $this->ok([
            'statistics' => [
                'total_invoices' => $total,
                'paid_invoices' => $paid,
                'unpaid_invoices' => $unpaid,
                'total_amount' => (float) $totalAmount,
                'paid_amount' => (float) $paidAmount,
                'unpaid_amount' => (float) $unpaidAmount,
            ],
        ]);
    }

    /**
     * Dummy payment endpoint - marks invoice as paid when VA is copied
     * This is for development/testing only
     */
    public function dummyPay(Request $request, string $id)
    {
        $midtransService = app(\App\Services\MidtransService::class);
        if (!app()->environment('local', 'testing') && !$midtransService->isMockMode()) {
            return $this->error('Dummy payment is disabled in production with live Midtrans credentials.', 403);
        }

        $user = $request->user();

        $serviceAccountIds = $user->serviceAccounts()->pluck('id');

        $invoice = Invoice::with('serviceAccount')
            ->whereIn('service_account_id', $serviceAccountIds)
            ->find($id);

        if (!$invoice) {
            return $this->error('Invoice not found.', 404);
        }

        if ($invoice->status === 'paid') {
            return $this->error('Invoice already paid.', 400);
        }

        // Mark as paid
        $invoice->update([
            'status' => 'paid',
            'paid_at' => now(),
        ]);

        // Create dummy payment record
        $invoice->payments()->create([
            'amount' => $invoice->total_amount,
            'payment_method' => 'va_' . strtolower($this->vaService->getBankFromVA($invoice->va_number ?? '')),
            'provider_transaction_id' => 'DUMMY_' . strtoupper(uniqid()),
        ]);

        return $this->ok([
            'message' => 'Payment successful',
            'invoice' => [
                'id' => $invoice->id,
                'invoice_number' => $invoice->invoice_number,
                'total_amount' => (float) $invoice->total_amount,
                'status' => $invoice->status,
                'paid_at' => $invoice->paid_at?->toIso8601String(),
            ],
        ]);
    }
}
