# Retrieve OPAS annual statistics for a series

Downloads pre-computed annual statistics for a single data series.
Compared to `opas_get_station_stats`, this endpoint targets one specific
parameter × station combination and returns all applicable statistics
and limits for that series.

## Usage

``` r
opas_get_series_stats(series_id, year, auth = NULL)
```

## Arguments

  - series\_id:
    
    Integer. Series identifier as returned by `opas_series` (`series_id`
    column).

  - year:
    
    Integer or character. Four-digit year (e.g. `2025`). Must be a
    completed year.

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per statistic × limit combination. See
`opas_get_station_stats` for a description of the columns; note that
`parameter_id` is not returned by this endpoint.

## Details

Only complete years are available; the current year returns no results
as statistics are computed at year-end.

## Examples

``` r
if (FALSE) { # \dontrun{
opas_get_series_stats(series_id = 12900, year = 2025)

# Stateless authentication object
auth <- opas_auth("user@arpa.fvg.it", "my_password")
opas_get_series_stats(12900, 2025, auth = auth)
} # }
```
