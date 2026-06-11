# Retrieve updated measurements for all series in a region

Downloads all measurements for every series in a given region that have
been inserted or modified after `since`.

## Usage

``` r
opas_sync_region(region, since, auth = NULL)
```

## Arguments

  - region:
    
    Character. ISTAT region code (e.g. `"06"`). Zero-padded
    automatically if needed.

  - since:
    
    POSIXct or ISO 8601 character string. See `opas_sync_series` for
    details.

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A named list of `tibble`s, one per station-series pair. Names use the
form `"station_<station_id>_series_<series_id>"` when identifiers are
available. Missing identifiers receive stable fallback names.

## Details

**Warning**: this endpoint can return extremely large datasets. Use with
a recent `since` value (e.g. last 24 hours) for routine incremental
synchronisation. For historical backfills, prefer `opas_sync_station`
called iteratively per station.

## Examples

``` r
if (FALSE) { # \dontrun{
since   <- as.POSIXct(Sys.time() - 86400, tz = "Etc/GMT-1")
updates <- opas_sync_region("06", since = since)
dplyr::bind_rows(updates[sapply(updates, nrow) > 0])
} # }
```
