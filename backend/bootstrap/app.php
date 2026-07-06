<?php

use App\Http\Middleware\AdminOnly;
use App\Http\Middleware\EnsureNotBanned;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
        // Broadcast channels + their Sanctum-guarded auth route are registered
        // in App\Providers\BroadcastServiceProvider (so /broadcasting/auth uses
        // bearer tokens, not the web guard). Hence no `channels:` here.
    )
    ->withMiddleware(function (Middleware $middleware) {
        // API stateless defaults — bearer-token first, Sanctum stateful for SPA.
        $middleware->statefulApi();

        // Named middleware aliases consumed by route groups.
        $middleware->alias([
            'banned' => EnsureNotBanned::class,
            'admin' => AdminOnly::class,
        ]);

        // Trust proxies for correct scheme/host behind load balancers.
        $middleware->trustProxies(at: '*');

        // This is an API-only backend. Unauthenticated API requests must return
        // JSON 401 responses instead of redirecting to a non-existent web login.
        $middleware->redirectGuestsTo(fn () => null);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        // Always render JSON for the API surface.
        $exceptions->shouldRenderJsonWhen(function ($request) {
            return $request->is('api/*') || $request->expectsJson();
        });
    })->create();
