# VitaAI Beta

VitaAI is an early-stage health information app built with React, TypeScript, TanStack Start, Supabase, and PostgreSQL. The current codebase is a foundation for a future AI health assistant; it is not yet a complete or clinically validated chatbot.

## Current status

- A starter library of 14 provisional articles is defined in the database migration.
- PostgreSQL full-text search and public read-only article access are set up.
- Retrieval and medical-safety helper functions exist.
- The current route tree contains only the homepage. A working chat interface and model-backed chat API have not yet been implemented.
- Tests and production deployment have not been verified.

Treat all health articles as educational and provisional. Check every article and source against the original authoritative source before relying on or publishing it as verified. VitaAI does not diagnose or replace professional medical care. In an emergency, contact local emergency services.

## Getting started

Requirements: Node.js and Bun (the repository includes `bun.lock`).

1. Copy `.env.example` to `.env` and fill in the Supabase project settings.
2. Install dependencies with `bun install`.
3. Start the development server with `bun run dev`.

Available scripts:

- `bun run dev` — local development server
- `bun run build` — production build
- `bun run lint` — lint the code
- `bun run test` — run the current test suite

The database migration and starter seed are in `drizzle/migrations/0000_migration.sql`. Review the Supabase and Drizzle configuration before applying database changes.

## Configuration

Set the following environment variables locally:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Never commit `.env` or server secrets. No AI provider secret or working chat endpoint is included in this beta snapshot.

## Safety and privacy limits

This beta does not provide diagnosis, personalized treatment, or medication dosing. It does not currently implement chat-history persistence. The emergency checks are keyword heuristics and cannot identify every emergency. Do not enter real patient data.

## License

No open-source license has been selected. Until a license is added, standard copyright restrictions apply.
