# Get current OPAS authentication object

Returns the currently stored authentication state as an object of class
`"ropas_auth"`.

## Usage

``` r
opas_current_auth()
```

## Value

An object of class `"ropas_auth"`.

## Details

This is mainly useful for advanced workflows, including process-based
parallel execution, where the current token needs to be passed
explicitly to worker processes.

## Examples

``` r
if (FALSE) { # \dontrun{
opas_login("user@arpa.fvg.it", "my_password")
auth <- opas_current_auth()
} # }
```
