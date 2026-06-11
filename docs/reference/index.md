# Package index

## Authentication

Login, explicit authentication objects, and session management.

<!-- end list -->

  - `opas_login()` : Login to OPAS API
  - `opas_auth()` : Create an OPAS authentication object
  - `opas_current_auth()` : Get current OPAS authentication object
  - `opas_logout()` : Logout from OPAS API

## Metadata

Stations, sites, campaigns, parameters, and series catalogues.

<!-- end list -->

  - `opas_stations()` : List OPAS monitoring stations
  - `opas_station()` : Get detailed metadata for a single OPAS station
  - `opas_sites()` : List OPAS monitoring sites
  - `opas_campaigns()` : Retrieve OPAS station campaign allocations
  - `opas_station_parameters()` : Retrieve station parameters for a
    specific OPAS station and parameter
  - `opas_parameters()` : List OPAS measured parameters
  - `opas_parameter()` : Get detailed metadata for a single OPAS
    parameter
  - `opas_parameter_types()` : List OPAS parameter types
  - `opas_series()` : List available OPAS data series

## Measurements

Hourly and daily measurement data.

<!-- end list -->

  - `opas_get_data()` : Retrieve OPAS time series measurements

## Station logs

Station log events over date-time ranges.

<!-- end list -->

  - `opas_station_log()` : Retrieve OPAS station log events

## Incremental synchronisation

Endpoints for retrieving inserted or updated measurements.

<!-- end list -->

  - `opas_sync_series()` : Retrieve updated measurements for a single
    series
  - `opas_sync_station()` : Retrieve updated measurements for all series
    at a station
  - `opas_sync_region()` : Retrieve updated measurements for all series
    in a region

## Statistics and regulatory limits

Annual statistics and lookup tables for regulatory limits.

<!-- end list -->

  - `opas_get_station_stats()` : Retrieve OPAS annual statistics for a
    station
  - `opas_get_series_stats()` : Retrieve OPAS annual statistics for a
    series
  - `opas_limits()` : Get OPAS regulatory limits
  - `opas_statistics()` : Get OPAS statistic types
  - `opas_statistics_limits()` : Get OPAS statistic-pollutant-limit
    combinations
