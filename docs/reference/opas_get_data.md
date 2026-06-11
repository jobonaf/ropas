# Retrieve OPAS time series measurements

Downloads measurement data for a single data series from the OPAS API.
Three retrieval modes are supported:

## Usage

``` r
opas_get_data(
  series_id,
  start = NULL,
  end = NULL,
  last_hours = NULL,
  last_days = NULL,
  daily = FALSE,
  auth = NULL
)
```

## Arguments

  - series\_id:
    
    Integer. Series identifier as returned by `opas_series` (`series_id`
    column).

  - start, end:
    
    Start and end of the requested period. Accepted inputs:
    
      - A `POSIXct` object.
    
      - A character string in ISO 8601 format `"YYYY-MM-DDTHH:MM:SS"`,
        interpreted as UTC+1 fixed (`"Etc/GMT-1"`).
    
    Both must be supplied together.

  - last\_hours:
    
    Integer. Return data for the last *N* hours. Mutually exclusive with
    `last_days` and `start`/`end`.

  - last\_days:
    
    Integer. Return daily-aggregated data for the last *N* days.
    Mutually exclusive with `last_hours` and `start`/`end`.

  - daily:
    
    Logical. When using a custom `start`/`end` range, set `TRUE` to use
    the daily-aggregated endpoint (`/series-data-dd/`) instead of the
    raw hourly one (`/series-data/`). Ignored when `last_hours` or
    `last_days` is supplied.

  - auth:
    
    Optional object returned by `opas_auth`. If supplied, it is used
    instead of the package-global authentication state. This is useful
    for process-based parallel workflows.

## Value

A `tibble` with one row per measurement, including:

  - datetime:
    
    `POSIXct` in UTC+1 fixed (`"Etc/GMT-1"`), derived from
    `measure_date_time`. See the note on timestamps in the Details
    section.

  - value\_raw:
    
    `measure_value` as returned by the API; the source column
    `measure_value` is dropped.

  - post\_validity\_code:
    
    Primary validity flag when provided by the API (0 = valid, 1 =
    reconstructed, negative = invalid).

  - series\_id, station\_id, station\_name, parameter\_name,
    parameter\_unit:
    
    Series context columns, prepended for convenience. `parameter_unit`
    is the raw measurement unit returned by the data endpoint.

  - ...:
    
    All remaining API fields except `measure_value` and
    `measure_date_time`, which are replaced by `value_raw` and
    `datetime` respectively.

## Details

  - **Recent hours**: supply `last_hours`.

  - **Recent days** (daily-aggregated endpoint): supply `last_days`.

  - **Custom range**: supply both `start` and `end`. Use `daily = TRUE`
    to hit the daily-aggregated endpoint instead of the raw hourly one.

**Note on `measure_value`**: the API returns raw instrument values. This
function exposes them as `value_raw`. Conversion metadata is available
from catalogue endpoints such as `opas_series` and `opas_parameters`.
Automatic conversion is intentionally left to higher-level helper
functions.

**Note on validity**: filter on `post_validity_code` to keep only the
records you trust: `0` = valid, `1` = reconstructed, negative = invalid.

**Note on timestamps**: `measure_date_time` strings returned by the OPAS
API carry no explicit timezone offset and always represent Italian
standard time (UTC+1 fixed, no daylight saving), as confirmed by ISPRA
developers. This is consistent with the legal reference time required by
D.Lgs. 155/2010 and EU Directive 2024/2881. The `datetime` column is
parsed with `tz = "Etc/GMT-1"`. For daily aggregates (`last_days` or
`daily = TRUE`), each record is timestamped at midnight (`00:00:00`) of
the reference day.

## Examples

``` r
if (FALSE) { # \dontrun{
# Last 24 hours
opas_get_data(12900, last_hours = 24)

# Last 7 daily aggregates
opas_get_data(12900, last_days = 7)

# Custom range (raw hourly)
opas_get_data(12900,
              start = "2026-01-01T00:00:00",
              end   = "2026-02-01T00:00:00")

# Custom range (daily aggregates)
opas_get_data(12900,
              start = "2026-01-01T00:00:00",
              end   = "2026-02-01T00:00:00",
              daily = TRUE)

# Stateless authentication object, useful in parallel workflows
auth <- opas_auth("user@arpa.fvg.it", "my_password")
opas_get_data(12900, last_hours = 24, auth = auth)
} # }
```
