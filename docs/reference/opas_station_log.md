# Retrieve OPAS station log events

Retrieves log events for a station over a date-time range.

## Usage

``` r
opas_station_log(station_id, start, end, auth = NULL)
```

## Arguments

  - station\_id:
    
    Integer. Station identifier as returned by `opas_stations`.

  - start, end:
    
    Start and end of the requested period. Accepted inputs:
    
      - A `POSIXct` object.
    
      - A character string in ISO 8601 format `"YYYY-MM-DDTHH:MM:SS"`,
        interpreted as UTC+1 fixed (`"Etc/GMT-1"`).
    
    Both must be supplied.

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. Useful for
    process-based parallel workflows.

## Value

A `tibble` with one row per station log event. Key columns:

  - log\_id:
    
    Unique log identifier.

  - log\_date:
    
    Event date-time as `POSIXct` in UTC+1 fixed (`"Etc/GMT-1"`), when
    returned by the API.

  - log\_daily:
    
    Logical flag indicating daily log events.

  - station\_id, station\_name:
    
    Station identifiers.

  - lt\_name:
    
    Log type name.

  - log\_title:
    
    Log title.

  - log\_link:
    
    URL to the OPAS portal, when available.

  - log\_obj:
    
    List-column containing structured log details such as `desc` and
    `title`.

  - log\_insert\_ts, log\_update\_ts:
    
    Database timestamps parsed as `POSIXct` in UTC, when returned by the
    API.

## Examples

``` r
if (FALSE) { # \dontrun{
opas_station_log(
  station_id = 1167,
  start = "2026-01-01T00:00:00",
  end   = "2026-02-01T00:00:00"
)

auth <- opas_auth("user@arpa.fvg.it", "my_password")
opas_station_log(
  station_id = 1167,
  start = "2026-01-01T00:00:00",
  end   = "2026-02-01T00:00:00",
  auth = auth
)
} # }
```
