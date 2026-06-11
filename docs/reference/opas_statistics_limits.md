# Get OPAS statistic-pollutant-limit combinations

Retrieves the full cross-reference table linking pollutants, statistic
types, and regulatory limits, including the temporal validity of each
limit. This is the pre-joined version of `opas_limits` and
`opas_statistics`.

## Usage

``` r
opas_statistics_limits(auth = NULL)
```

## Arguments

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per statistic × pollutant × limit combination:

  - stat\_poll\_id:
    
    Unique identifier for the statistic-pollutant combination; foreign
    key in statistics results.

  - stat\_poll\_type:
    
    Aggregation period: `"D"` = daily, `"M"` = monthly, `"Y"` = annual.

  - stat\_poll\_active:
    
    Logical; whether this combination is active.

  - pollutant\_id, parameter\_id, pollutant\_name:
    
    Pollutant identifiers.

  - statistic\_id, statistic\_description, statistic\_active:
    
    Statistic type fields.

  - limit\_id, limit\_description, limit\_threshold, limit\_exceedances,
    limit\_unit:
    
    Limit definition fields.

  - limit\_from, limit\_to:
    
    Temporal validity of the limit as character strings; `"-infinity"`
    and `"infinity"` are left as-is and are not coerced to `Date`.

## Details

Useful for understanding which limits apply to a given pollutant and
statistic, and for interpreting the `limit_id` column returned by
`opas_get_station_stats` and `opas_get_series_stats`.

## Examples

``` r
if (FALSE) { # \dontrun{
sl <- opas_statistics_limits()

# Annual limits only
sl[sl$stat_poll_type == "Y", ]

# All limits for NO2
sl[sl$pollutant_name == "NO2", ]

auth <- opas_auth("user@arpa.fvg.it", "my_password")
opas_statistics_limits(auth = auth)
} # }
```
