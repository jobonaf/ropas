# List OPAS monitoring sites

Retrieves the table of OPAS monitoring sites.

## Usage

``` r
opas_sites(auth = NULL)
```

## Arguments

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per site. Key columns:

  - site\_id:
    
    Unique site identifier.

  - site\_name:
    
    Site name.

  - wgs84\_lat, wgs84\_lon:
    
    Geographic coordinates.

  - altitude:
    
    Site altitude.

  - municipality\_name, province\_name, region\_name:
    
    Administrative location fields.

  - network\_names:
    
    List-column with network names associated with the site.

## Details

Sites represent physical locations where stations may be allocated,
including geographic coordinates and associated network names.

## Examples

``` r
if (FALSE) { # \dontrun{
sites <- opas_sites()

auth <- opas_auth("user@arpa.fvg.it", "my_password")
sites <- opas_sites(auth = auth)
} # }
```
