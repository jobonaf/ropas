# List OPAS parameter types

Retrieves the classification of parameters into categories (e.g.
*Chimici*, *Meteo*). Useful for filtering the output of
`opas_parameters` by category.

## Usage

``` r
opas_parameter_types(auth = NULL)
```

## Arguments

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per parameter type, containing at minimum a type
identifier and a description.

## Examples

``` r
if (FALSE) { # \dontrun{
opas_parameter_types()
} # }
```
