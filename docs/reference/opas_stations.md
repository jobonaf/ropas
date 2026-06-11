# List OPAS monitoring stations

Retrieves metadata for OPAS monitoring stations. Results can be
optionally filtered by ISTAT region code.

## Usage

``` r
opas_stations(region = NULL, auth = NULL)
```

## Arguments

  - region:
    
    Character or integer. ISTAT region code. Single-digit values are
    accepted and padded automatically, e.g. `6` or `"6"` become `"06"`.
    Valid values: `"01"`–`"20"`.

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per station. The `id` and `name` fields from the
API are renamed to `station_id` and `station_name` for consistency with
other package functions when present.

## Details

The national catalogue is not large (a few hundred stations) and can be
downloaded without filtering.

## Examples

``` r
if (FALSE) { # \dontrun{
# All stations in Friuli-Venezia Giulia
opas_stations(region = "06")

# Equivalent
opas_stations(region = 6)

# All stations — national catalogue
opas_stations()
} # }
```
