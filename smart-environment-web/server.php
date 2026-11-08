<?php

/**
 * Laravel - A PHP Framework For Web Artisans
 *
 * Emulates Apache "mod_rewrite" functionality from the built-in PHP web server,
 * while ensuring CORS headers are added for static files in /storage/ (e.g. photos)
 * without duplicating CORS headers for Laravel API routes.
 */

$publicPath = __DIR__ . '/public';

$uri = urldecode(
    parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? ''
);

// Serve /storage/ files directly with CORS headers
if ($uri !== '/' && str_starts_with($uri, '/storage/') && file_exists($publicPath . $uri)) {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, OPTIONS');
    header('Access-Control-Allow-Headers: Origin, Content-Type, Accept, Authorization, X-Requested-With');

    if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit(0);
    }

    $mime = mime_content_type($publicPath . $uri) ?: 'application/octet-stream';
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . filesize($publicPath . $uri));
    readfile($publicPath . $uri);
    exit(0);
}

// If other public files exist, let PHP serve them
if ($uri !== '/' && file_exists($publicPath . $uri)) {
    return false;
}

require_once $publicPath . '/index.php';
