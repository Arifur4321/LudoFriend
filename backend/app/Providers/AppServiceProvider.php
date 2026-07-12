<?php

namespace App\Providers;

use App\Models\GameRoom;
use App\Models\Matchup;
use App\Policies\MatchPolicy;
use App\Policies\RoomPolicy;
use App\Services\Game\LudoRules;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register application services.
     */
    public function register(): void
    {
        // LudoRules is stateless and reads config('ludo') — bind as a singleton
        // so the engine and every consumer share one instance.
        $this->app->singleton(LudoRules::class, fn () => new LudoRules(config('ludo')));
    }

    /**
     * Bootstrap application services.
     */
    public function boot(): void
    {
        $this->registerRouteBindings();
        $this->registerPolicies();
        $this->registerRateLimiters();
    }

    /**
     * Bind the {match} route parameter to the Matchup model (the param name
     * cannot be "matchup" without renaming routes, and "match" does not
     * auto-resolve to a model named Matchup).
     */
    private function registerRouteBindings(): void
    {
        Route::model('match', Matchup::class);
    }

    /**
     * Map models to their authorization policies.
     */
    private function registerPolicies(): void
    {
        Gate::policy(GameRoom::class, RoomPolicy::class);
        Gate::policy(Matchup::class, MatchPolicy::class);

        // Admin ability used by the AdminOnly middleware / AdminController.
        Gate::define('admin', fn ($user) => (bool) ($user->is_admin ?? false));
    }

    /**
     * Configure named rate limiters (knobs sourced from config/env).
     */
    private function registerRateLimiters(): void
    {
        $authLimit = (int) env('RATE_LIMIT_AUTH', 6);
        $gameLimit = (int) env('RATE_LIMIT_GAME', 30);
        $apiLimit = (int) env('RATE_LIMIT_API', 60);
        $chatLimit = (int) env('RATE_LIMIT_CHAT', config('chat.rate_per_minute', 20));
        $emojiLimit = (int) env('RATE_LIMIT_EMOJI', config('chat.emoji_rate_per_minute', 15));

        RateLimiter::for('auth', fn (Request $request) => Limit::perMinute($authLimit)
            ->by($request->ip()));

        RateLimiter::for('game', fn (Request $request) => Limit::perMinute($gameLimit)
            ->by(optional($request->user())->id ?: $request->ip()));

        RateLimiter::for('api', fn (Request $request) => Limit::perMinute($apiLimit)
            ->by(optional($request->user())->id ?: $request->ip()));

        // Dedicated chat/emoji limiters, keyed per authenticated user (guests
        // included) so one spammer cannot flood a table or starve game actions.
        RateLimiter::for('chat', fn (Request $request) => Limit::perMinute($chatLimit)
            ->by(optional($request->user())->id ?: $request->ip()));

        RateLimiter::for('emoji', fn (Request $request) => Limit::perMinute($emojiLimit)
            ->by(optional($request->user())->id ?: $request->ip()));
    }
}
