# Create an OPAS authentication object

Authenticates with the OPAS web service and returns an authentication
object containing the access token, refresh token, and expiry time.

## Usage

``` r
opas_auth(email, password)
```

## Arguments

  - email:
    
    Email address registered on the OPAS portal.

  - password:
    
    Corresponding password.

## Value

An object of class `"ropas_auth"` containing:

  - token:
    
    JWT access token.

  - refresh\_token:
    
    Refresh token returned by OPAS.

  - expires\_at:
    
    Token expiry time as `POSIXct` in UTC.

## Details

Unlike `opas_login`, this function does not modify the package internal
authentication state. It is useful for advanced workflows, especially
process-based parallel execution, where worker processes should receive
authentication explicitly rather than relying on the package-global
authentication environment.

## Examples

``` r
if (FALSE) { # \dontrun{
auth <- opas_auth("my@email.it", "my_password")
} # }
```
