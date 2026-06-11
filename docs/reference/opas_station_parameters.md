# Retrieve station parameters for a specific OPAS station and parameter

Retrieves detailed station metadata and the corresponding parameter
series metadata for a given station-parameter combination.

## Usage

``` r
opas_station_parameters(station_id, parameter_id, auth = NULL)
```

## Arguments

  - station\_id:
    
    Integer. Station identifier as returned by `opas_stations`.

  - parameter\_id:
    
    Integer. Parameter identifier as returned by `opas_parameters`.

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A named list with two elements:

  - station:
    
    A one-row `tibble` with station metadata.

  - parameters:
    
    A `tibble` with one row per matching parameter series. Key columns
    include `series_id`, `parameter_id`, `parameter_name`,
    `parameter_unit`, `parameter_conv_curr`, and `parameter_conv_unit`.
    `conversion_history` is preserved as a list-column.

## Details

The returned structure is intentionally consistent with `opas_station`:
a named list with a one-row station tibble and a parameter-series
tibble.

## Examples

``` r
if (FALSE) { # \dontrun{
opas_station_parameters(station_id = 1167, parameter_id = 34)

auth <- opas_auth("user@arpa.fvg.it", "my_password")
opas_station_parameters(1167, 34, auth = auth)
} # }
```
