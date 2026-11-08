<?php

namespace App\Services;

use Midtrans\Config;
use Midtrans\Snap;
use Midtrans\Transaction;
use Midtrans\CoreApi;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

class MidtransService
{
    public function __construct()
    {
        $this->configureMidtrans();
    }

    /**
     * Check if currently running in mock/sandbox simulator mode
     */
    public function isMockMode(): bool
    {
        $serverKey = config('midtrans.server_key');
        if (empty($serverKey) || str_contains($serverKey, 'DUMMY') || config('midtrans.mock', false)) {
            return true;
        }
        return false;
    }

    /**
     * Configure Midtrans settings
     */
    private function configureMidtrans(): void
    {
        Config::$serverKey = config('midtrans.server_key') ?: 'SB-Mid-server-DUMMY';
        Config::$isProduction = config('midtrans.is_production', false);
        Config::$isSanitized = config('midtrans.is_sanitized', true);
        Config::$is3ds = config('midtrans.is_3ds', true);
    }

    /**
     * Create payment transaction
     * 
     * @param array $params Payment parameters
     * @return array Transaction details
     */
    public function createTransaction(array $params): array
    {
        if ($this->isMockMode()) {
            return $this->createMockTransaction($params);
        }

        try {
            $transaction = [
                'transaction_details' => [
                    'order_id' => $params['order_id'],
                    'gross_amount' => $params['gross_amount'],
                ],
                'customer_details' => [
                    'first_name' => $params['customer_name'],
                    'email' => $params['customer_email'],
                    'phone' => $params['customer_phone'] ?? '',
                ],
                'item_details' => $params['items'],
            ];

            // Add payment type specific configuration
            if (isset($params['payment_type'])) {
                $transaction['enabled_payments'] = $this->getEnabledPayments($params['payment_type']);
                
                // Set expiry
                $expiryMinutes = $this->getExpiryMinutes($params['payment_type']);
                $transaction['expiry'] = [
                    'start_time' => now()->format('Y-m-d H:i:s O'),
                    'unit' => 'minutes',
                    'duration' => $expiryMinutes,
                ];
            }

            // For specific payment channel (VA, gopay, shopeepay, qris)
            if (isset($params['payment_channel'])) {
                return $this->createChargeTransaction($params);
            }

            // Use Snap for general payment
            $snapToken = Snap::getSnapToken($transaction);
            
            return [
                'success' => true,
                'snap_token' => $snapToken,
                'order_id' => $params['order_id'],
            ];

        } catch (\Exception $e) {
            Log::error('Midtrans Create Transaction Error: ' . $e->getMessage());
            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Create charge transaction for specific payment channel
     * 
     * @param array $params
     * @return array
     */
    private function createChargeTransaction(array $params): array
    {
        try {
            $transaction = [
                'payment_type' => $this->mapPaymentType($params['payment_channel']),
                'transaction_details' => [
                    'order_id' => $params['order_id'],
                    'gross_amount' => $params['gross_amount'],
                ],
                'customer_details' => [
                    'first_name' => $params['customer_name'],
                    'email' => $params['customer_email'],
                    'phone' => $params['customer_phone'] ?? '',
                ],
                'item_details' => $params['items'],
            ];

            // Add channel-specific parameters
            $channel = $params['payment_channel'];
            
            // Determine if it's a VA channel
            $isVA = in_array($channel, ['bca', 'bni', 'bri', 'permata']) || str_ends_with($channel, '_va');
            
            if ($isVA) {
                // Bank Transfer (VA)
                $bank = str_replace('_va', '', $channel);
                $transaction['bank_transfer'] = ['bank' => $bank];
                
                // For Permata VA
                if ($bank === 'permata') {
                    $transaction['bank_transfer']['va_number'] = $this->generateVANumber();
                }
                
            } elseif ($channel === 'qris') {
                // QRIS
                $transaction['qris'] = ['acquirer' => 'gopay'];
                
            } elseif ($channel === 'gopay') {
                // GoPay
                $transaction['gopay'] = [
                    'enable_callback' => true,
                    'callback_url' => config('midtrans.finish_url'),
                ];
                
            } elseif ($channel === 'shopeepay') {
                // ShopeePay
                $transaction['shopeepay'] = [
                    'callback_url' => config('midtrans.finish_url'),
                ];
            }

            $response = CoreApi::charge($transaction);
            
            return $this->parseChargeResponse($response, $params['payment_channel']);

        } catch (\Exception $e) {
            Log::error('Midtrans Charge Error: ' . $e->getMessage());
            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Parse charge response based on payment channel
     * 
     * @param object $response
     * @param string $channel
     * @return array
     */
    private function parseChargeResponse(object $response, string $channel): array
    {
        $result = [
            'success' => true,
            'order_id' => $response->order_id,
            'transaction_id' => $response->transaction_id,
            'status' => $response->transaction_status,
            'payment_type' => $response->payment_type,
        ];

        // Determine if it's a VA channel
        $isVA = in_array($channel, ['bca', 'bni', 'bri', 'permata']) || str_ends_with($channel, '_va');
        
        // VA Response
        if ($isVA) {
            $result['va_number'] = $response->va_numbers[0]->va_number ?? null;
            $result['bank'] = $response->va_numbers[0]->bank ?? str_replace('_va', '', $channel);
        }

        // QRIS Response
        if ($channel === 'qris') {
            $result['qr_string'] = $response->actions[0]->url ?? null;
        }

        // E-Wallet Response (GoPay, ShopeePay)
        if (in_array($channel, ['gopay', 'shopeepay'])) {
            // Find deeplink action
            foreach ($response->actions as $action) {
                if ($action->name === 'deeplink-redirect') {
                    $result['payment_url'] = $action->url;
                    break;
                }
            }
            
            // Fallback to generate qr if available
            if (!isset($result['payment_url']) && isset($response->actions[0]->url)) {
                $result['payment_url'] = $response->actions[0]->url;
            }
        }

        // Add expiry
        if (isset($response->expiry_time)) {
            $result['expired_at'] = $response->expiry_time;
        }

        return $result;
    }

    /**
     * Create mock transaction for sandbox testing when Midtrans keys are not set
     */
    private function createMockTransaction(array $params): array
    {
        $channel = $params['payment_channel'] ?? 'qris';
        $orderId = $params['order_id'];
        $amount = (int) $params['gross_amount'];

        $result = [
            'success' => true,
            'order_id' => $orderId,
            'transaction_id' => 'SANDBOX-' . strtoupper(uniqid()),
            'status' => 'pending',
            'payment_type' => $this->mapPaymentType($channel),
            'expired_at' => now()->addMinutes($this->getExpiryMinutes($params['payment_type'] ?? 'qris'))->toIso8601String(),
        ];

        $isVA = in_array($channel, ['bca', 'bni', 'bri', 'permata', 'mandiri']) || str_ends_with($channel, '_va');

        if ($isVA) {
            $bank = str_replace('_va', '', $channel);
            $prefix = match(strtolower($bank)) {
                'bca' => '70012',
                'bni' => '8808',
                'bri' => '10777',
                'mandiri' => '89608',
                default => '8808',
            };
            // 14-digit realistic VA number
            $vaNumber = $prefix . rand(100000000, 999999999);
            $result['va_number'] = $vaNumber;
            $result['bank'] = $bank;
        } elseif ($channel === 'qris') {
            // Standard valid EMVCo QRIS string format for mobile QrImageView
            $result['qr_string'] = '00020101021226540014ID.LINKAJA.WWW011893600911002220743602150000000000000000303UMI51440014ID.CO.QRIS.WWW0215ID10200210000020303UMI52045499530336054' . str_pad((string)$amount, 5, '0', STR_PAD_LEFT) . '5802ID5907BERESIN6010TANGERANG61051511162070703A016304' . strtoupper(substr(md5($orderId), 0, 4));
        } elseif (in_array($channel, ['gopay', 'shopeepay'])) {
            $result['payment_url'] = 'https://simulator.sandbox.midtrans.com/gopay/partner/app/payment-pin?id=' . $orderId;
        }

        Log::info('Midtrans Sandbox Mock Transaction Created', [
            'order_id' => $orderId,
            'channel' => $channel,
            'amount' => $amount,
        ]);

        return $result;
    }

    /**
     * Check transaction status
     * 
     * @param string $orderId
     * @return array
     */
    public function getTransactionStatus(string $orderId): array
    {
        if ($this->isMockMode()) {
            $payment = \App\Models\Payment::where('order_id', $orderId)->first();
            if ($payment) {
                return [
                    'success' => true,
                    'order_id' => $orderId,
                    'transaction_status' => $payment->status === 'success' ? 'settlement' : $payment->status,
                    'payment_type' => $payment->payment_type ?? 'qris',
                    'transaction_time' => $payment->created_at?->format('Y-m-d H:i:s') ?? now()->format('Y-m-d H:i:s'),
                    'gross_amount' => $payment->amount,
                    'fraud_status' => 'accept',
                ];
            }
        }

        try {
            $status = Transaction::status($orderId);
            
            return [
                'success' => true,
                'order_id' => $status->order_id,
                'transaction_status' => $status->transaction_status,
                'payment_type' => $status->payment_type,
                'transaction_time' => $status->transaction_time,
                'gross_amount' => $status->gross_amount,
                'fraud_status' => $status->fraud_status ?? null,
            ];

        } catch (\Exception $e) {
            Log::error('Midtrans Get Status Error: ' . $e->getMessage());
            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Verify notification signature
     * 
     * @param array $notification
     * @return bool
     */
    public function verifySignature(array $notification): bool
    {
        $orderId = $notification['order_id'];
        $statusCode = $notification['status_code'];
        $grossAmount = $notification['gross_amount'];
        $serverKey = config('midtrans.server_key');

        $signature = hash('sha512', $orderId . $statusCode . $grossAmount . $serverKey);

        return $signature === $notification['signature_key'];
    }

    /**
     * Map payment channel to Midtrans payment type
     * 
     * @param string $channel
     * @return string
     */
    private function mapPaymentType(string $channel): string
    {
        return match (true) {
            str_ends_with($channel, '_va') => 'bank_transfer',
            $channel === 'qris' => 'qris',
            $channel === 'gopay' => 'gopay',
            $channel === 'shopeepay' => 'shopeepay',
            default => 'bank_transfer',
        };
    }

    /**
     * Get enabled payments for Snap based on payment type
     * 
     * @param string $paymentType
     * @return array
     */
    private function getEnabledPayments(string $paymentType): array
    {
        return match ($paymentType) {
            'va' => ['bank_transfer'],
            'qris' => ['qris'],
            'ewallet' => ['gopay', 'shopeepay'],
            default => config('midtrans.enabled_payments'),
        };
    }

    /**
     * Get expiry minutes based on payment type
     * 
     * @param string $paymentType
     * @return int
     */
    private function getExpiryMinutes(string $paymentType): int
    {
        return match ($paymentType) {
            'va' => config('midtrans.expiry.bank_transfer', 1440),
            'qris' => config('midtrans.expiry.qris', 30),
            'ewallet' => config('midtrans.expiry.gopay', 15),
            default => 1440,
        };
    }

    /**
     * Generate VA number for Permata
     * 
     * @return string
     */
    private function generateVANumber(): string
    {
        return '8' . str_pad(rand(0, 9999999999), 9, '0', STR_PAD_LEFT);
    }

    /**
     * Cancel transaction
     * 
     * @param string $orderId
     * @return array
     */
    public function cancelTransaction(string $orderId): array
    {
        try {
            $response = Transaction::cancel($orderId);
            
            return [
                'success' => true,
                'order_id' => $response->order_id,
                'status' => $response->transaction_status,
            ];

        } catch (\Exception $e) {
            Log::error('Midtrans Cancel Error: ' . $e->getMessage());
            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }
}
