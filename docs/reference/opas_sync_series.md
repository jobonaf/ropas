# Retrieve updated measurements for a single series

Downloads all measurements for one data series that have been inserted
or modified after `since`. This endpoint is designed for incremental
synchronisation: store the timestamp of the last successful sync and
pass it as `since` on the next run.

## Usage

``` r
opas_sync_series(series_id, since, auth = NULL)
```

## Arguments

  - series\_id:
    
    Integer. Series identifier from `opas_series`.

  - since:
    
    POSIXct or ISO 8601 character string (`"YYYY-MM-DDTHH:MM:SS"`). Only
    records inserted or updated after this timestamp are returned.
    Character input is interpreted as Italian standard time (UTC+1
    fixed).

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per updated measurement, or an empty tibble if
no updates are available. Includes all fields from `opas_get_data` plus:

  - measure\_insert\_ts:
    
    `POSIXct` (UTC) of initial insertion.

  - measure\_update\_ts:
    
    `POSIXct` (UTC) of last modification.

  - measure\_update\_obj:
    
    List-column; audit log of changes with old and new validity codes
    and values.

## Details

The response includes both newly inserted records and records whose
validity codes were updated after the initial insertion.
`measure_update_ts` indicates when each record was last modified;
`measure_update_obj` (list-column) contains the full audit log of
changes.

## Note

The `series_id` column in the returned tibble reflects the internal OPAS
series identifier as returned by the API, which may differ from the
`series_id` used to query the endpoint. Use `opas_series` to reconcile
the two identifiers.

## Examples

``` r
if (FALSE) { # \dontrun{
# Records updated since 1 June 2026
opas_sync_series(12900, since = "2026-06-01T00:00:00")

# Stateless authentication object
auth <- opas_auth("user@arpa.fvg.it", "my_password")
opas_sync_series(12900, since = "2026-06-01T00:00:00", auth = auth)
} # }
```
