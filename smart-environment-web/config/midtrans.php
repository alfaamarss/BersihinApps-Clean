<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Midtrans Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for Midtrans payment gateway integration.
    | Get your credentials from: https://dashboard.midtrans.com
    |
    */

    'merchant_id' => env('MIDTRANS_MERCHANT_ID'),
    'client_key' => env('MIDTRANS_CLIENT_KEY'),
    'server_key' => env('MIDTRANS_SERVER_KEY'),
    'mock' => env('MIDTRANS_MOCK', true),
    
    /*
    |--------------------------------------------------------------------------
    | Environment Settings
    |--------------------------------------------------------------------------
    |
    | is_production: false for sandbox, true for production
    | is_sanitized: Enable input sanitization
    | is_3ds: Enable 3D Secure for credit card
    |
    */
    
    'is_production' => env('MIDTRANS_IS_PRODUCTION', false),
    'is_sanitized' => env('MIDTRANS_IS_SANITIZED', true),
    'is_3ds' => env('MIDTRANS_IS_3DS', true),

    /*
    |--------------------------------------------------------------------------
    | Payment Methods Configuration
    |--------------------------------------------------------------------------
    */

    'enabled_payments' => [
        'bank_transfer' => [
            'bca',
            'bni',
            'bri',
            'mandiri',
            'permata',
        ],
        'echannel' => [
            'mandiri',
        ],
        'gopay',
        'shopeepay',
        'qris',
    ],

    /*
    |--------------------------------------------------------------------------
    | Payment Expiry Settings (in minutes)
    |--------------------------------------------------------------------------
    */

    'expiry' => [
        'bank_transfer' => 1440, // 24 hours
        'gopay' => 15,           // 15 minutes
        'shopeepay' => 15,       // 15 minutes
        'qris' => 30,            // 30 minutes
    ],

    /*
    |--------------------------------------------------------------------------
    | Notification URL
    |--------------------------------------------------------------------------
    |
    | URL for receiving payment notifications from Midtrans
    | Must be publicly accessible (not localhost)
    |
    */

    'notification_url' => env('APP_URL') . '/api/midtrans/webhook',

    /*
    |--------------------------------------------------------------------------
    | Redirect URLs
    |--------------------------------------------------------------------------
    */

    'finish_url' => env('APP_URL') . '/payment/finish',
    'unfinish_url' => env('APP_URL') . '/payment/unfinish',
    'error_url' => env('APP_URL') . '/payment/error',
];
