# Get detailed metadata for a single OPAS parameter

Retrieves full metadata for one parameter by ID, including raw unit,
conversion factor, reporting unit, aggregation settings, and conversion
history.

## Usage

``` r
opas_parameter(parameter_id, auth = NULL)
```

## Arguments

  - parameter\_id:
    
    Integer. Parameter identifier as returned by the `parameter_id`
    column of `opas_parameters`.

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A one-row `tibble` with all parameter fields. `conversion_history` is
preserved as a list-column; `date_from`/`date_to` entries of
`"-infinity"` and `"infinity"` are left as character strings.

## Examples

``` r
if (FALSE) { # \dontrun{
opas_parameter(7)   # Pressione
opas_parameter(29)  # SO2
} # }
```
