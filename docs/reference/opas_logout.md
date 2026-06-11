# Logout from OPAS API

Invalidates the current session on the server and clears all
authentication state from the internal environment.

## Usage

``` r
opas_logout()
```

## Value

Invisibly returns `TRUE`.

## Details

Server-side logout is attempted on a best-effort basis. Local
authentication state is cleared regardless of whether the server-side
logout request succeeds.

After calling this function, `opas_login` must be called again before
making API requests through the default interactive authentication
workflow.

## Examples

``` r
if (FALSE) { # \dontrun{
opas_logout()
} # }
```
