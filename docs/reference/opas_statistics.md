# Get OPAS statistic types

Retrieves the table of statistic types defined in the OPAS system (e.g.
hourly mean, daily mean, annual mean).

## Usage

``` r
opas_statistics(auth = NULL)
```

## Arguments

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per statistic type:

  - statistic\_id:
    
    Unique statistic identifier.

  - statistic\_description:
    
    Human-readable description (e.g. `"Media"`, `"Media giornaliera"`).

  - statistic\_active:
    
    Logical; whether the statistic is currently in use.

  - statistic\_order:
    
    Display order.

## Details

This is a static reference table. For the mapping between statistics,
pollutants, and regulatory limits, use `opas_statistics_limits`.

## Examples

``` r
if (FALSE) { # \dontrun{
opas_statistics()

auth <- opas_auth("user@arpa.fvg.it", "my_password")
opas_statistics(auth = auth)
} # }
```
