# Login to OPAS API

Authenticates with the OPAS web service and stores the JWT access token
and refresh token internally. Must be called before any other API
function when using the default interactive authentication workflow.

## Usage

``` r
opas_login(email, password)
```

## Arguments

  - email:
    
    Email address registered on the OPAS portal.

  - password:
    
    Corresponding password.

## Value

Invisibly returns `TRUE` on success.

## Details

The token is valid for approximately 1 hour; subsequent calls are
handled automatically by `opas_ensure_token()`.

For parallel workflows, prefer `opas_auth` and pass the returned object
explicitly to API functions that support an `auth` argument.

## Examples

``` r
if (FALSE) { # \dontrun{
opas_login("user@arpa.fvg.it", "my_password")
} # }
```
