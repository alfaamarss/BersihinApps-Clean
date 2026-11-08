<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->trustProxies(at: '*');

        $middleware->alias([
            'role' => \Spatie\Permission\Middleware\RoleMiddleware::class,
            'permission' => \Spatie\Permission\Middleware\PermissionMiddleware::class,
            'role_or_permission' => \Spatie\Permission\Middleware\RoleOrPermissionMiddleware::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        $exceptions->render(function (Throwable $e, Illuminate\Http\Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            $makeResponse = function (bool $success, $data, int $status, $message = null, $errors = []) {
                return response()->json([
                    'success' => $success,
                    'data' => $data,
                    'meta' => (object) [],
                    'errors' => $success ? [] : [
                        'message' => $message,
                        'details' => $errors,
                    ],
                ], $status);
            };

            if ($e instanceof Illuminate\Validation\ValidationException) {
                return $makeResponse(false, null, 422, 'Validation error', $e->errors());
            }
            if ($e instanceof Illuminate\Auth\AuthenticationException) {
                return $makeResponse(false, null, 401, 'Unauthenticated');
            }
            if ($e instanceof Illuminate\Auth\Access\AuthorizationException) {
                return $makeResponse(false, null, 403, 'Forbidden');
            }
            if ($e instanceof Spatie\Permission\Exceptions\UnauthorizedException) {
                return $makeResponse(false, null, 403, 'Forbidden');
            }
            if ($e instanceof Illuminate\Database\Eloquent\ModelNotFoundException) {
                return $makeResponse(false, null, 404, 'Resource not found');
            }
            if ($e instanceof \Symfony\Component\HttpKernel\Exception\HttpExceptionInterface) {
                $status = $e->getStatusCode();
                $message = match ($status) {
                    404 => 'Resource not found',
                    405 => 'Method not allowed',
                    403 => 'Forbidden',
                    401 => 'Unauthenticated',
                    409 => 'Conflict',
                    default => $e->getMessage() ?: 'HTTP error',
                };
                return $makeResponse(false, null, $status, $message);
            }

            \Illuminate\Support\Facades\Log::error($e->getMessage(), ['exception' => $e]);
            return $makeResponse(false, null, 500, 'Server error');
        });
    })->create();
