# Retrieve OPAS station campaign allocations

Retrieves campaign allocation metadata for a station. If `at` is
supplied, only campaigns active at that date-time are returned.

## Usage

``` r
opas_campaigns(station_id, at = NULL, auth = NULL)
```

## Arguments

  - station\_id:
    
    Integer. Station identifier as returned by `opas_stations`.

  - at:
    
    Optional date-time used to filter active campaigns. Accepted inputs
    are:
    
      - A `POSIXct` object.
    
      - A character string in ISO 8601 format `"YYYY-MM-DDTHH:MM:SS"`,
        interpreted as UTC+1 fixed (`"Etc/GMT-1"`).

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per allocation, or an empty tibble if no
campaigns are available for the query. Key columns:

  - station\_id, station\_name:
    
    Station identifiers.

  - station\_override\_id, station\_external\_id:
    
    Additional station identifiers returned by the API.

  - site\_id, site\_name:
    
    Site identifiers.

  - site\_locality:
    
    Site locality.

  - site\_wgs84\_lat, site\_wgs84\_lon:
    
    Site coordinates.

  - allocation\_startup\_date, allocation\_dismiss\_date:
    
    Allocation period as `POSIXct` in UTC+1 fixed (`"Etc/GMT-1"`), when
    returned by the API.

  - network\_names:
    
    List-column with network names.

  - ...:
    
    Additional allocation or campaign fields returned by the API, such
    as `campaign_id` and `campaign_name` when available.

## Examples

``` r
if (FALSE) { # \dontrun{
# All campaigns for a station
opas_campaigns(1167)

# Campaigns active at a specific date-time
opas_campaigns(1167, at = "2026-06-01T00:00:00")

auth <- opas_auth("user@arpa.fvg.it", "my_password")
opas_campaigns(1167, auth = auth)
} # }
```
