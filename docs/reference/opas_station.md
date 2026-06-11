# Get detailed metadata for a single OPAS station

Retrieves full metadata for one station by ID, including the list of all
parameters (data series) currently or historically measured at that
station.

## Usage

``` r
opas_station(station_id, auth = NULL)
```

## Arguments

  - station\_id:
    
    Integer. Station identifier as returned by the `station_id` column
    of `opas_stations`.

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A named list with two elements:

  - station:
    
    A one-row `tibble` with station metadata.

  - parameters:
    
    A `tibble` with one row per parameter measured at the station. When
    present, fields are renamed consistently to `parameter_name`,
    `parameter_unit`, `parameter_conv_curr`, and `parameter_conv_unit`.
    The `conversion_history` column is preserved as a list-column.

## Examples

``` r
if (FALSE) { # \dontrun{
det <- opas_station(1167)
det$station
det$parameters
} # }
```
