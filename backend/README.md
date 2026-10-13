# Café kitchen service

Production runs through `api/index.mjs` on Vercel and stores rooms/tickets in Lakebase Postgres on Neon. `worker/index.js` is the shared request handler; `neon_adapter.mjs` binds SQL parameters and executes atomic transactions.

The game never receives the database URL. A till creates a room with separate random POS and kitchen credentials. Only SHA-256 hashes are stored in the rooms table. The POS credential submits orders; the kitchen credential advances New → Preparing → Done. Every price comes from the server menu. Submission uses a nonce for safe retries, including when the room reaches capacity. Status changes compare the expected previous status atomically.

Rooms expire in seven days, with 100 tickets per room and 1,000 active rooms. CORS permits the public game, the owner's GitHub Pages origin, and local development. Native clients send credentials in an Authorization header over HTTPS. No payment processing occurs.

```sh
npm ci
vercel env pull .env.local
npm run db:migrate
npm run test:backend
npm run dev:backend
```

Run these from the repository root. Migration source is `migrations/001_postgres.sql`; use the direct `DATABASE_URL_UNPOOLED` connection for migrations and pooled `DATABASE_URL` for application queries. Keep the environment file ignored.

The development server binds only to `127.0.0.1:8790` with a real SQLite file under ignored `work/`. `drizzle/0000_cafe.sql` supplies that fixture schema, separate from live Postgres.

`tests/security.mjs` checks real SQLite-backed API behavior. `tools/test_network.py --endpoint https://cafe-shift-rush-hour.vercel.app` proves the actual live service with two independent Godot processes, then revokes the temporary test room. Sanitized client logs are in `docs/sync-proof.json`.
