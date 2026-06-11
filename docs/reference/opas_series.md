# List available OPAS data series

Retrieves the catalogue of data series from the OPAS API. Each series
corresponds to one parameter measured at one station, and carries the
`series_id` needed to download measurements via `opas_get_data`.

## Usage

``` r
opas_series(region = NULL, station = NULL, auth = NULL)
```

## Arguments

  - region:
    
    Character or integer. ISTAT region code. Single-digit values are
    accepted and padded automatically, e.g. `6` or `"6"` become `"06"`.
    Valid values: `"01"`–`"20"`.

  - station:
    
    Integer or character. Station ID as returned by the `station_id`
    column of `opas_stations`.

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per series. Key columns include:

  - series\_id:
    
    Unique series identifier; use this with `opas_get_data`.

  - station\_id, station\_name:
    
    Station identifiers.

  - parameter\_id, parameter\_name:
    
    Parameter identifiers.

  - parameter\_unit:
    
    Raw measurement unit, e.g. `"ppb"`.

  - parameter\_conv\_curr:
    
    Current conversion factor used to transform raw measurements into
    the reporting unit.

  - parameter\_conv\_unit:
    
    Reporting unit after applying `parameter_conv_curr`, e.g. `"µg/m³"`.

  - region\_istat\_code, region\_name:
    
    Region identifiers.

## Details

Exactly one of `region` or `station` should normally be supplied.
Calling the function with no arguments fetches the full catalogue, which
can be a large object; a confirmation prompt is shown in interactive
sessions.

## Examples

``` r
if (FALSE) { # \dontrun{
# All series for Friuli-Venezia Giulia
opas_series(region = "06")

# Equivalent
opas_series(region = 6)

# All series for a specific station
opas_series(station = 1167)

# Stateless authentication object
auth <- opas_auth("user@arpa.fvg.it", "my_password")
opas_series(region = "06", auth = auth)
} # }
```
