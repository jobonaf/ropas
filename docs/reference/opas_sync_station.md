# Retrieve updated measurements for all series at a station

Downloads all measurements for every series at a given station that have
been inserted or modified after `since`. The response covers all
parameters measured at the station; series with no updates since `since`
return an empty tibble.

## Usage

``` r
opas_sync_station(station_id, since, auth = NULL)
```

## Arguments

  - station\_id:
    
    Integer. Station identifier from `opas_stations`.

  - since:
    
    POSIXct or ISO 8601 character string. See `opas_sync_series` for
    details.

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A named list of `tibble`s, one per series. Names are usually
`"series_<series_id>"`. If a series identifier is missing, a stable
fallback name is generated.

## Details

This endpoint can return very large datasets if `since` is far in the
past. For the first full load of a station, consider using
`opas_get_data` with an explicit date range instead.

## Examples

``` r
if (FALSE) { # \dontrun{
updates <- opas_sync_station(1167, since = "2026-06-01T00:00:00")
updates[sapply(updates, nrow) > 0]
} # }
```
