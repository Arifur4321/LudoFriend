# Documentation index

| Doc | What |
|-----|------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design, client + backend layers, server-authoritative model |
| [GAME_RULES.md](GAME_RULES.md) | Rule set & the engine board model (and what's tested) |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Env config, builds, backend ops, enabling FB/ads/IAP, security |
| [../backend/API_REFERENCE.md](../backend/API_REFERENCE.md) | REST endpoints (method, path, auth, request/response) |
| [../backend/WEBSOCKETS.md](../backend/WEBSOCKETS.md) | WebSocket events (channel, trigger, payload) |
| [../app/assets/README_ASSETS.md](../app/assets/README_ASSETS.md) | Asset inventory, palette, SVG→WebP & icon generation |
| [../app/README.md](../app/README.md) | Flutter app setup, run, test |
| [../backend/README.md](../backend/README.md) | Laravel setup, migrate, reverb, queues |

## Deliverables map

1. **Flutter app** — `app/`
2. **Laravel backend** — `backend/`
3. **DB migrations** — `backend/database/migrations/` (15+ domain tables)
4. **API docs** — `backend/API_REFERENCE.md`
5. **WebSocket docs** — `backend/WEBSOCKETS.md`
6. **README / setup** — root + `app/` + `backend/`
7. **Assets (SVG/Lottie/SFX)** — `app/assets/` (+ generation notes)
8. **Animations** — Flutter `CustomPainter`/`AnimationController` code + Lottie
9. **Tests** — `app/test/` (engine + widget + repo) and `backend/tests/`
10. **Production notes** — `docs/DEPLOYMENT.md`
