# List OPAS measured parameters

Retrieves metadata for all parameters measured by OPAS stations,
including raw units, conversion factors, reporting units, and
aggregation settings.

## Usage

``` r
opas_parameters(auth = NULL)
```

## Arguments

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per parameter. Key columns:

  - parameter\_id:
    
    Unique parameter identifier.

  - parameter\_name:
    
    Human-readable parameter name, e.g. `"NO2"`.

  - parameter\_unit:
    
    Raw measurement unit used by the instrument, e.g. `"ppb"`.

  - parameter\_conv\_curr:
    
    Current conversion factor used to transform raw measurements into
    the reporting unit.

  - parameter\_conv\_unit:
    
    Reporting unit after applying `parameter_conv_curr`, e.g. `"µg/m³"`.

  - conversion\_history:
    
    List-column with historical conversion factors; relevant for long
    time series spanning conversion changes.

## Examples

``` r
if (FALSE) { # \dontrun{
params <- opas_parameters()
params[, c("parameter_id", "parameter_name", "parameter_unit",
           "parameter_conv_curr", "parameter_conv_unit")]
} # }
```
