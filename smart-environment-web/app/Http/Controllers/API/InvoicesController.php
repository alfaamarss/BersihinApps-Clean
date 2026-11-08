<?php

namespace App\Http\Controllers\API;

use App\Models\Invoice;
use App\Models\Payment;
use App\Services\VirtualAccountService;
use App\Support\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class InvoicesController extends BaseResourceController
{
    protected string $modelClass = Invoice::class;
    protected array $rulesStore = [
        'waste_delivery_id' => 'required|exists:waste_deliveries,id|unique:invoices,waste_delivery_id',
        'service_account_id' => 'required|exists:service_accounts,id',
        'invoice_number' => 'required|string|unique:invoices,invoice_number',
        'total_amount' => 'required|numeric',
        'status' => 'sometimes|in:not_paid,paid,cancelled',
        'issued_at' => 'sometimes|date',
        'bank' => 'sometimes|in:bca,mandiri,bni,bri,permata',
        'va_expiry_days' => 'sometimes|integer|min:1|max:30',
    ];
    protected array $rulesUpdate = [
        'waste_delivery_id' => 'sometimes|exists:waste_deliveries,id|unique:invoices,waste_delivery_id',
        'service_account_id' => 'sometimes|exists:service_accounts,id',
        'invoice_number' => 'sometimes|string|unique:invoices,invoice_number',
        'va_number' => 'nullable|string|unique:invoices,va_number',
        'va_expiry_at' => 'nullable|date',
        'total_amount' => 'sometimes|numeric',
        'status' => 'sometimes|in:not_paid,paid,cancelled',
        'issued_at' => 'sometimes|date',
        'paid_at' => 'nullable|date',
    ];
    protected array $filterable = ['status','invoice_number'];
    protected array $sortable = ['id','issued_at'];
    protected ?string $permissionPrefix = 'invoice';

    protected VirtualAccountService $vaService;

    public function __construct(VirtualAccountService $vaService)
    {
        parent::__construct();
        $this->vaService = $vaService;
    }

    /**
     * Override store to auto-generate VA number
     */
    public function store(Request $request)
    {
        $validated = $request->validate($this->rulesStore);

        // Auto-generate VA number and expiry
        $bank = $validated['bank'] ?? 'bca';
        $expiryDays = $validated['va_expiry_days'] ?? null;

        $validated['va_number'] = $this->vaService->generateVANumber($bank);
        $validated['va_expiry_at'] = $expiryDays
            ? $this->vaService->generateExpiryDate($expiryDays)
            : $this->vaService->generateMonthEndExpiry();
        $validated['status'] = $validated['status'] ?? 'not_paid';
        $validated['issued_at'] = $validated['issued_at'] ?? Carbon::now();

        // Remove non-database fields
        unset($validated['bank'], $validated['va_expiry_days']);

        try {
            $invoice = Invoice::create($validated);
            
            return ApiResponse::created($invoice->load(['serviceAccount', 'wasteDelivery']), 'Invoice created successfully with VA number');
        } catch (\Exception $e) {
            return ApiResponse::error('Failed to create invoice: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Confirm payment for an invoice (simulate payment gateway webhook)
     * POST /api/v1/invoices/{id}/confirm-payment
     */
    public function confirmPayment(Request $request, $id)
    {
        if (!Auth::user()?->hasRole('admin')) {
            return ApiResponse::error('Unauthorized. Only administrators can manually confirm invoice payments.', 403);
        }

        $validated = $request->validate([
            'amount' => 'required|numeric|min:0',
            'payment_method' => 'required|string|in:va_bca,va_mandiri,va_bni,va_bri,va_permata,cash,transfer',
            'provider_transaction_id' => 'nullable|string',
            'paid_at' => 'sometimes|date',
        ]);

        $invoice = Invoice::find($id);
        
        if (!$invoice) {
            return ApiResponse::notFound('Invoice not found');
        }

        if ($invoice->status === 'paid') {
            return ApiResponse::error('Invoice already paid', 400);
        }

        if ($invoice->status === 'cancelled') {
            return ApiResponse::error('Invoice is cancelled', 400);
        }

        // Check if VA is expired
        if ($invoice->va_expiry_at && $this->vaService->isExpired($invoice->va_expiry_at)) {
            return ApiResponse::error('Virtual Account has expired', 400);
        }

        try {
            DB::beginTransaction();

            // Create payment record
            $payment = Payment::create([
                'invoice_id' => $invoice->id,
                'amount' => $validated['amount'],
                'payment_method' => $validated['payment_method'],
                'provider_transaction_id' => $validated['provider_transaction_id'] ?? 'DEMO-' . time(),
                'paid_at' => $validated['paid_at'] ?? Carbon::now(),
            ]);

            // Calculate total paid amount
            $totalPaid = $invoice->payments()->sum('amount');

            // Update invoice status if fully paid
            if ($totalPaid >= $invoice->total_amount) {
                $invoice->update([
                    'status' => 'paid',
                    'paid_at' => $payment->paid_at,
                ]);
            }

            DB::commit();

            return ApiResponse::success([
                'invoice' => $invoice->fresh()->load(['payments', 'serviceAccount', 'wasteDelivery']),
                'payment' => $payment,
                'total_paid' => $totalPaid,
                'remaining' => max(0, $invoice->total_amount - $totalPaid),
            ], 'Payment confirmed successfully');

        } catch (\Exception $e) {
            DB::rollBack();
            return ApiResponse::error('Failed to confirm payment: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Check VA status and validity
     * GET /api/v1/invoices/{id}/va-status
     */
    public function checkVAStatus($id)
    {
        $invoice = Invoice::with(['payments', 'serviceAccount', 'wasteDelivery'])->find($id);
        
        if (!$invoice) {
            return ApiResponse::notFound('Invoice not found');
        }

        $isExpired = $invoice->va_expiry_at ? $this->vaService->isExpired($invoice->va_expiry_at) : false;
        $bank = $this->vaService->getBankFromVA($invoice->va_number);
        $formattedVA = $this->vaService->formatVADisplay($invoice->va_number);

        return ApiResponse::success([
            'invoice' => $invoice,
            'va_info' => [
                'va_number' => $invoice->va_number,
                'va_number_formatted' => $formattedVA,
                'bank' => strtoupper($bank ?? 'unknown'),
                'expiry_at' => $invoice->va_expiry_at,
                'is_expired' => $isExpired,
                'status' => $invoice->status,
            ],
            'payment_info' => [
                'total_amount' => $invoice->total_amount,
                'total_paid' => $invoice->payments->sum('amount'),
                'remaining' => max(0, $invoice->total_amount - $invoice->payments->sum('amount')),
            ],
        ]);
    }
}
