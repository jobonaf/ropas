# Get OPAS regulatory limits

Retrieves the table of regulatory limit definitions used by the OPAS
system. Each row defines a limit threshold and the maximum number of
allowed exceedances per year for a given pollutant statistic.

## Usage

``` r
opas_limits(auth = NULL)
```

## Arguments

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per limit definition:

  - limit\_id:
    
    Unique limit identifier; used as a foreign key in
    `opas_statistics_limits` and in statistics results.

  - limit\_description:
    
    Human-readable description including pollutant, statistic type,
    threshold, and allowed exceedances.

  - limit\_threshold:
    
    Numerical threshold value.

  - limit\_exceedances:
    
    Maximum number of allowed exceedances per year; `NA` when no
    exceedance count applies.

  - limit\_unit:
    
    Physical unit of the threshold.

## Details

This is a static reference table; it does not contain observed
exceedances. For observed results against limits, use
`opas_get_station_stats` or `opas_get_series_stats`.

## Examples

``` r
if (FALSE) { # \dontrun{
opas_limits()

auth <- opas_auth("user@arpa.fvg.it", "my_password")
opas_limits(auth = auth)
} # }
```
