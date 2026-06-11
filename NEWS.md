# ropas 0.1.0

## New features

- Added authentication workflows with explicit `auth` objects.
- Added metadata endpoints for stations, sites, campaigns, parameters and series.
- Added hourly and daily measurement retrieval.
- Added incremental synchronisation endpoints.
- Added annual statistics and regulatory limit lookup endpoints.
- Added station log endpoint.
- Added OPAS API contract tests.

## Improvements

- Added robust parsing for optional and nested API fields.
- Added fallback handling for gzip-compressed responses without usable `Content-Encoding`.
- Added diagnostic options via `ropas.verbose` and `ropas.warn_unexpected_gzip`.
- Added technical notes on OPAS API field semantics.
