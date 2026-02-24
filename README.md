# DaktarPi

Flutter application for doctor discovery, appointment booking, medical records, and account security flows.

## Documentation

Comprehensive technical documentation is available at:

- `docs/COMPREHENSIVE_CODEBASE_DOCUMENTATION.md`

## Quick Start

1. Install Flutter SDK and mobile toolchains.
2. Create `.env` with required keys:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `GOOGLE_WEB_CLIENT_ID`
3. Run:

```bash
flutter pub get
flutter run
```

## Route Provider Cut-over (Production)

The Supabase Edge Function `supabase/functions/route-proxy` supports:
- `ROUTE_PROVIDER=osrm` (default, non-production fallback)
- `ROUTE_PROVIDER=mapbox`
- `ROUTE_PROVIDER=google`

Provider credentials:
- Mapbox: `MAPBOX_ACCESS_TOKEN` (optional `MAPBOX_BASE_URL`)
- Google Routes: `GOOGLE_MAPS_API_KEY` (or `GOOGLE_ROUTES_API_KEY`) and optional `GOOGLE_ROUTES_BASE_URL`

For HIPAA-sensitive production traffic, configure a BAA-backed provider account (Mapbox Enterprise or Google Maps Mobility), then set `ROUTE_PROVIDER` and keys in your Supabase function environment.
