# ropas

![](reference/figures/logo.png)

`ropas` is an R client for the [OPAS](https://opas.isprambiente.it)
(OPen Air System) REST API.

The package provides access to OPAS web-service endpoints for:

  - station metadata;
  - parameter metadata;
  - data series catalogues;
  - hourly and daily measurements;
  - incremental synchronisation endpoints;
  - pre-computed annual statistics and regulatory limit reference
    tables.

OPAS is used by some Italian environmental agencies. `ropas` does not
assume that OPAS represents the full official national air-quality
network; it simply provides an R interface to the available API
endpoints.

## Installation

``` r
# install.packages("devtools")
devtools::install_github("jobonaf/ropas")
```

## Quick start

``` r
library(ropas)

# Authenticate for an interactive session
opas_login("your@email.it", "yourpassword")

# Browse available series for Friuli-Venezia Giulia (ISTAT code "06")
series <- opas_series(region = "06")

series[, c(
  "series_id",
  "station_name",
  "parameter_name",
  "parameter_unit",
  "parameter_conv_curr",
  "parameter_conv_unit"
)]

# Download the last 24 hours for a known series
data <- opas_get_data(series_id = 12900, last_hours = 24)

data
```

`opas_get_data()` returns raw measurement values as provided by the API.
Higher-level helpers for joins, unit conversion and quality filtering
may be added in future versions.

## Authentication

Interactive workflows can use:

``` r
opas_login("your@email.it", "yourpassword")
```

Authentication state is stored internally for the current R session and
is used automatically by API functions.

For advanced or process-based parallel workflows, use an explicit
authentication object:

``` r
auth <- opas_auth("your@email.it", "yourpassword")
```

Functions that support an `auth` argument can then receive this object
explicitly, avoiding reliance on package-global authentication state in
worker processes:

``` r
series <- opas_series(region = "06", auth = auth)
data   <- opas_get_data(series_id = 12900, last_hours = 24, auth = auth)
```

You can retrieve the current internal authentication state with:

``` r
auth <- opas_current_auth()
```

Logout clears local authentication state and attempts server-side logout
on a best-effort basis:

``` r
opas_logout()
```

## Diagnostics

Request-level diagnostic messages can be enabled with:

``` r
options(ropas.verbose = TRUE)
```

This prints basic request/response information, such as the endpoint
path and HTTP status code.

Some OPAS endpoints may return gzip-compressed responses without a
usable `Content-Encoding` header. `ropas` applies a fallback manual
decompression strategy and warns when this happens. In operational
pipelines, these warnings can be disabled with:

``` r
options(ropas.warn_unexpected_gzip = FALSE)
```

## Main functions

### Authentication

| Function                      | Description                                                               |
| ----------------------------- | ------------------------------------------------------------------------- |
| `opas_login(email, password)` | Authenticate and store credentials internally for the current R session   |
| `opas_auth(email, password)`  | Return an explicit authentication object without modifying internal state |
| `opas_current_auth()`         | Return the current internal authentication object                         |
| `opas_logout()`               | Clear authentication state and attempt server-side logout                 |

### Metadata

| Function                                                  | Description                                                        |
| --------------------------------------------------------- | ------------------------------------------------------------------ |
| `opas_stations(region = NULL, auth = NULL)`               | List monitoring stations, optionally filtered by ISTAT region code |
| `opas_station(station_id, auth = NULL)`                   | Retrieve detailed metadata for a single station                    |
| `opas_parameters(auth = NULL)`                            | List measured parameters and conversion metadata                   |
| `opas_parameter(parameter_id, auth = NULL)`               | Retrieve detailed metadata for a single parameter                  |
| `opas_parameter_types(auth = NULL)`                       | List OPAS parameter categories                                     |
| `opas_series(region = NULL, station = NULL, auth = NULL)` | List available data series                                         |

### Measurements

| Function                                     | Description                                       |
| -------------------------------------------- | ------------------------------------------------- |
| `opas_get_data(series_id, ..., auth = NULL)` | Download hourly or daily time series measurements |

### Synchronisation

| Function                                            | Description                                                           |
| --------------------------------------------------- | --------------------------------------------------------------------- |
| `opas_sync_series(series_id, since, auth = NULL)`   | Retrieve records inserted or updated after a timestamp for one series |
| `opas_sync_station(station_id, since, auth = NULL)` | Retrieve updated records for all series at one station                |
| `opas_sync_region(region, since, auth = NULL)`      | Retrieve updated records for all series in a region                   |

### Statistics and regulatory limits

| Function                                                | Description                                 |
| ------------------------------------------------------- | ------------------------------------------- |
| `opas_limits(auth = NULL)`                              | Retrieve regulatory limit definitions       |
| `opas_statistics(auth = NULL)`                          | Retrieve statistic type definitions         |
| `opas_statistics_limits(auth = NULL)`                   | Retrieve statistic-pollutant-limit mappings |
| `opas_get_station_stats(station_id, year, auth = NULL)` | Retrieve annual statistics for a station    |
| `opas_get_series_stats(series_id, year, auth = NULL)`   | Retrieve annual statistics for a series     |

## Retrieving data

`opas_get_data()` supports three retrieval modes.

``` r
# Last N hours: raw hourly data
opas_get_data(series_id = 12900, last_hours = 24)

# Last N days: daily aggregates
opas_get_data(series_id = 12900, last_days = 30)

# Custom range: hourly data
opas_get_data(
  series_id = 12900,
  start = "2026-01-01T00:00:00",
  end   = "2026-03-31T23:59:59"
)

# Custom range: daily aggregates
opas_get_data(
  series_id = 12900,
  start = "2026-01-01T00:00:00",
  end   = "2026-03-31T23:59:59",
  daily = TRUE
)
```

The returned tibble includes context columns such as:

  - `series_id`;
  - `station_id`;
  - `station_name`;
  - `parameter_name`;
  - `parameter_unit`.

The measurement column is:

  - `value_raw`: raw value returned by the API.

The original API column `measure_value` is replaced by `value_raw` for a
cleaner interface.

## Units and conversion factors

Measurement endpoints return raw instrument values. Conversion metadata
is available from catalogue endpoints such as `opas_series()` and
`opas_parameters()`:

  - `parameter_unit`: raw measurement unit;
  - `parameter_conv_curr`: current conversion factor;
  - `parameter_conv_unit`: reporting unit after conversion.

Automatic unit conversion is intentionally left to future higher-level
helpers.

## Validity codes

The `post_validity_code` column is the primary field for basic quality
filtering.

|   Code | Meaning                      |
| -----: | ---------------------------- |
|    `0` | Valid                        |
|    `1` | Reconstructed                |
|   `-1` | Suspect                      |
| `< -1` | Invalid for different causes |

A conservative filter for strictly valid values is:

``` r
data_valid <- data[data$post_validity_code == 0, ]
```

A broader filter that keeps valid and reconstructed values is:

``` r
data_usable <- data[data$post_validity_code >= 0, ]
```

Other validity-related fields such as `measure_code`,
`auto_validity_code`, `station_code`, and `final_validity_code` are
preserved in the output when provided by the API.

## Timestamps

`measure_date_time` strings returned by OPAS measurement endpoints do
not carry an explicit timezone offset.

They are parsed by `ropas` as Italian standard time, i.e. UTC+1 fixed
with no daylight saving adjustment, using:

``` r
tz = "Etc/GMT-1"
```

The parsed column is named `datetime`.

For daily aggregates (`last_days` or `daily = TRUE`), records are
timestamped at midnight (`00:00:00`) of the reference day.

Synchronisation timestamps such as `measure_insert_ts` and
`measure_update_ts` are parsed as UTC when returned by the corresponding
API endpoints.

## Incremental synchronisation

OPAS exposes endpoints for incremental updates.

Retrieve updates for a single series:

``` r
updates <- opas_sync_series(
  series_id = 12900,
  since = "2026-06-01T00:00:00"
)
```

Retrieve updates for all series at a station:

``` r
updates <- opas_sync_station(
  station_id = 1167,
  since = "2026-06-01T00:00:00"
)
```

Retrieve updates for all series in a region:

``` r
updates <- opas_sync_region(
  region = "06",
  since = "2026-06-01T00:00:00"
)
```

Region-level synchronisation can return very large results. Prefer
recent timestamps or station-level synchronisation for operational
pipelines.

## Annual statistics

Annual pre-computed statistics can be retrieved for stations or
individual series.

``` r
# Annual statistics for one station
stats_station <- opas_get_station_stats(
  station_id = 1167,
  year = 2025
)

# Annual statistics for one series
stats_series <- opas_get_series_stats(
  series_id = 12900,
  year = 2025
)
```

The statistics endpoints return pre-computed results and, when
applicable, regulatory limit information such as threshold values and
exceedance counts.

Reference tables are available through:

``` r
limits <- opas_limits()
stats  <- opas_statistics()
links  <- opas_statistics_limits()
```

## Region ISTAT codes

The API uses two-digit ISTAT region codes. Single-digit values such as
`6` or `"6"` are accepted and normalised internally to `"06"`.

Common examples:

| Code | Region                |
| ---: | --------------------- |
| `02` | Valle d’Aosta         |
| `04` | Trentino-Alto Adige   |
| `05` | Veneto                |
| `06` | Friuli-Venezia Giulia |
| `07` | Liguria               |
| `08` | Emilia-Romagna        |
| `09` | Toscana               |
| `10` | Umbria                |
| `11` | Marche                |
| `12` | Lazio                 |
| `13` | Abruzzo               |
| `15` | Campania              |
| `16` | Puglia                |

Use:

``` r
opas_stations(region = "06")
opas_series(region = "06")
```

## Development status

`ropas` is experimental.

The package currently prioritises faithful access to OPAS API endpoints.
Higher-level helpers for automatic joins, unit conversion, quality
filtering, and reporting workflows may be added in future versions.

## License

GPL-3.
