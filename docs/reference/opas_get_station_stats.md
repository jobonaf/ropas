# Retrieve OPAS annual statistics for a station

Downloads pre-computed annual statistics for all parameters measured at
a given station. Statistics include regulatory limit comparisons
(threshold, exceedances, compliance) where applicable.

## Usage

``` r
opas_get_station_stats(station_id, year, auth = NULL)
```

## Arguments

  - station\_id:
    
    Integer. Station identifier as returned by `opas_stations`
    (`station_id` column).

  - year:
    
    Integer or character. Four-digit year (e.g. `2025`). Must be a
    completed year.

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per statistic × limit combination, including:

  - series\_id, station\_id, parameter\_id, pollutant\_id:
    
    Identifiers linking to other catalogue tables.

  - stat\_poll\_id, stat\_poll\_type:
    
    Statistic-pollutant combination identifier and aggregation type
    (`"Y"`).

  - limit\_id, limit\_description, limit\_threshold, limit\_exceedances:
    
    Regulatory limit details; `NA` when no limit is defined for the
    statistic.

  - result\_from, result\_to:
    
    Coverage period as `Date` objects, when returned by the API.

  - result\_value:
    
    Computed statistic value.

  - result\_exceedance:
    
    Logical; `TRUE` if the limit threshold was exceeded.

  - result\_valid:
    
    Logical; `TRUE` if sufficient valid data were available to compute
    the statistic.

## Details

Only complete years are available; the current year returns no results
as statistics are computed at year-end.

Daily (`D`) and monthly (`M`) aggregation types exist in the API schema
but return no data in the current OPAS deployment. This function
therefore only supports annual (`Y`) statistics.

## Examples

``` r
if (FALSE) { # \dontrun{
# Annual statistics for station 1167, year 2025
opas_get_station_stats(station_id = 1167, year = 2025)

# Keep only results with a defined regulatory limit
stats <- opas_get_station_stats(1167, 2025)
stats[!is.na(stats$limit_id), ]

# Stateless authentication object
auth <- opas_auth("user@arpa.fvg.it", "my_password")
opas_get_station_stats(1167, 2025, auth = auth)
} # }
```
