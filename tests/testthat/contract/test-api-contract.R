library(testthat)
library(ropas)


skip_if_not(
  Sys.getenv("ROPAS_RUN_CONTRACT_TESTS") == "true",
  "Contract tests disabled"
)

skip_if(
  nchar(Sys.getenv("OPAS_USER")) == 0 ||
    nchar(Sys.getenv("OPAS_PASSWORD")) == 0,
  "No OPAS credentials — skipping contract tests"
)

auth <- opas_auth(
  email    = Sys.getenv("OPAS_USER"),
  password = Sys.getenv("OPAS_PASSWORD")
)

# Contract tests should fail on structural/API changes, not on known
# OPAS gzip-header inconsistencies already handled by ropas.
options(ropas.warn_unexpected_gzip = FALSE)

# Fixtures used by live contract tests.
fixture_region <- "06"
fixture_station_id <- 1167
fixture_station_with_campaigns <- 1135
fixture_parameter_id <- 34
fixture_series_id <- 12900
fixture_year <- 2025


test_that("authentication returns a valid auth object", {
  expect_s3_class(auth, "ropas_auth")
  expect_type(auth$token, "character")
  expect_gt(nchar(auth$token), 10)
  expect_type(auth$refresh_token, "character")
  expect_s3_class(auth$expires_at, "POSIXct")
})


test_that("opas_stations returns expected structure", {
  st <- opas_stations(region = fixture_region, auth = auth)
  
  expect_s3_class(st, "tbl_df")
  expect_gt(nrow(st), 0)
  
  expected_cols <- c(
    "station_id",
    "station_name",
    "region_istat_code",
    "region_name",
    "lat_wgs84",
    "lon_wgs84"
  )
  
  expect_true(
    all(expected_cols %in% names(st)),
    info = paste(
      "Missing columns:",
      paste(setdiff(expected_cols, names(st)), collapse = ", ")
    )
  )
})


test_that("opas_station returns station and parameters", {
  det <- opas_station(fixture_station_id, auth = auth)
  
  expect_type(det, "list")
  expect_true(all(c("station", "parameters") %in% names(det)))
  
  expect_s3_class(det$station, "tbl_df")
  expect_equal(nrow(det$station), 1)
  
  expect_true(all(c("station_id", "station_name") %in% names(det$station)))
  
  expect_s3_class(det$parameters, "tbl_df")
  expect_true(all(c(
    "series_id",
    "parameter_name",
    "parameter_unit"
  ) %in% names(det$parameters)))
})


test_that("opas_sites returns expected structure", {
  sites <- opas_sites(auth = auth)
  
  expect_s3_class(sites, "tbl_df")
  expect_gt(nrow(sites), 0)
  
  expected_cols <- c(
    "site_id",
    "site_name",
    "network_names",
    "wgs84_lat",
    "wgs84_lon"
  )
  
  expect_true(
    all(expected_cols %in% names(sites)),
    info = paste(
      "Missing columns:",
      paste(setdiff(expected_cols, names(sites)), collapse = ", ")
    )
  )
  
  expect_true(is.list(sites$network_names))
})


test_that("opas_campaigns returns non-empty allocations for known station", {
  camp <- opas_campaigns(fixture_station_with_campaigns, auth = auth)
  
  expect_s3_class(camp, "tbl_df")
  expect_gt(nrow(camp), 0)
  
  expected_cols <- c(
    "station_id",
    "station_name",
    "site_id",
    "site_name",
    "network_names",
    "allocation_startup_date",
    "allocation_dismiss_date"
  )
  
  expect_true(
    all(expected_cols %in% names(camp)),
    info = paste(
      "Missing columns:",
      paste(setdiff(expected_cols, names(camp)), collapse = ", ")
    )
  )
  
  expect_s3_class(camp$allocation_startup_date, "POSIXct")
  expect_s3_class(camp$allocation_dismiss_date, "POSIXct")
})


test_that("opas_station_parameters returns station and parameter details", {
  sp <- opas_station_parameters(
    station_id = fixture_station_id,
    parameter_id = fixture_parameter_id,
    auth = auth
  )
  
  expect_type(sp, "list")
  expect_true(all(c("station", "parameters") %in% names(sp)))
  
  expect_s3_class(sp$station, "tbl_df")
  expect_s3_class(sp$parameters, "tbl_df")
  
  expect_equal(nrow(sp$station), 1)
  
  expected_param_cols <- c(
    "series_id",
    "parameter_id",
    "parameter_name",
    "parameter_unit",
    "parameter_conv_curr",
    "parameter_conv_unit"
  )
  
  expect_true(
    all(expected_param_cols %in% names(sp$parameters)),
    info = paste(
      "Missing parameter columns:",
      paste(setdiff(expected_param_cols, names(sp$parameters)), collapse = ", ")
    )
  )
})


test_that("opas_parameters returns conversion metadata", {
  params <- opas_parameters(auth = auth)
  
  expect_s3_class(params, "tbl_df")
  expect_gt(nrow(params), 0)
  
  expected_cols <- c(
    "parameter_id",
    "parameter_name",
    "parameter_unit",
    "parameter_conv_curr",
    "parameter_conv_unit",
    "conversion_history"
  )
  
  expect_true(
    all(expected_cols %in% names(params)),
    info = paste(
      "Missing columns:",
      paste(setdiff(expected_cols, names(params)), collapse = ", ")
    )
  )
})


test_that("opas_parameter returns expected structure", {
  param <- opas_parameter(fixture_parameter_id, auth = auth)
  
  expect_s3_class(param, "tbl_df")
  expect_equal(nrow(param), 1)
  
  expected_cols <- c(
    "parameter_id",
    "parameter_name",
    "parameter_unit",
    "parameter_conv_curr",
    "parameter_conv_unit",
    "conversion_history"
  )
  
  expect_true(
    all(expected_cols %in% names(param)),
    info = paste(
      "Missing columns:",
      paste(setdiff(expected_cols, names(param)), collapse = ", ")
    )
  )
})


test_that("opas_parameter_types returns expected structure", {
  pt <- opas_parameter_types(auth = auth)
  
  expect_s3_class(pt, "tbl_df")
  expect_gt(nrow(pt), 0)
  expect_true(all(c("type_id", "type_name") %in% names(pt)))
})


test_that("opas_series returns expected structure", {
  series <- opas_series(region = fixture_region, auth = auth)
  
  expect_s3_class(series, "tbl_df")
  expect_gt(nrow(series), 0)
  
  expected_cols <- c(
    "series_id",
    "station_id",
    "station_name",
    "parameter_id",
    "parameter_name",
    "parameter_unit",
    "parameter_conv_curr",
    "parameter_conv_unit",
    "region_istat_code"
  )
  
  expect_true(
    all(expected_cols %in% names(series)),
    info = paste(
      "Missing columns:",
      paste(setdiff(expected_cols, names(series)), collapse = ", ")
    )
  )
})


test_that("opas_series works for station filter", {
  series_station <- opas_series(
    station = fixture_station_id,
    auth = auth
  )
  
  expect_s3_class(series_station, "tbl_df")
  expect_gt(nrow(series_station), 0)
  
  expected_cols <- c(
    "series_id",
    "station_id",
    "station_name",
    "parameter_id",
    "parameter_name",
    "parameter_unit",
    "parameter_conv_curr",
    "parameter_conv_unit"
  )
  
  expect_true(
    all(expected_cols %in% names(series_station)),
    info = paste(
      "Missing columns:",
      paste(setdiff(expected_cols, names(series_station)), collapse = ", ")
    )
  )
  
  expect_true(all(series_station$station_id == fixture_station_id))
})


test_that("opas_get_data returns expected structure for reference series", {
  data <- opas_get_data(
    series_id = fixture_series_id,
    last_hours = 72,
    auth = auth
  )
  
  expect_s3_class(data, "tbl_df")
  
  # This endpoint may occasionally return no recent data.
  # If data are returned, the structure must match the expected contract.
  if (nrow(data) > 0) {
    expected_cols <- c(
      "series_id",
      "station_id",
      "station_name",
      "parameter_name",
      "parameter_unit",
      "datetime",
      "value_raw",
      "post_validity_code"
    )
    
    expect_true(
      all(expected_cols %in% names(data)),
      info = paste(
        "Missing columns:",
        paste(setdiff(expected_cols, names(data)), collapse = ", ")
      )
    )
    
    expect_s3_class(data$datetime, "POSIXct")
    expect_type(data$value_raw, "double")
  }
})


test_that("opas_get_data daily endpoint returns expected structure when non-empty", {
  data_daily <- opas_get_data(
    series_id = fixture_series_id,
    last_days = 7,
    auth = auth
  )
  
  expect_s3_class(data_daily, "tbl_df")
  
  # This endpoint may return no recent daily data depending on the series
  # and API state. If data are returned, the structure must match.
  if (nrow(data_daily) > 0) {
    expected_cols <- c(
      "series_id",
      "station_id",
      "station_name",
      "parameter_name",
      "parameter_unit",
      "datetime",
      "value_raw",
      "post_validity_code"
    )
    
    expect_true(
      all(expected_cols %in% names(data_daily)),
      info = paste(
        "Missing columns:",
        paste(setdiff(expected_cols, names(data_daily)), collapse = ", ")
      )
    )
    
    expect_s3_class(data_daily$datetime, "POSIXct")
    expect_type(data_daily$value_raw, "double")
  }
})


test_that("opas_sync_series returns expected structure when non-empty", {
  sync <- opas_sync_series(
    series_id = fixture_series_id,
    since = "2026-06-01T00:00:00",
    auth = auth
  )
  
  expect_s3_class(sync, "tbl_df")
  
  if (nrow(sync) > 0) {
    expected_cols <- c(
      "series_id",
      "station_id",
      "station_name",
      "parameter_name",
      "parameter_unit",
      "datetime",
      "value_raw",
      "post_validity_code",
      "measure_insert_ts",
      "measure_update_ts"
    )
    
    expect_true(
      all(expected_cols %in% names(sync)),
      info = paste(
        "Missing columns:",
        paste(setdiff(expected_cols, names(sync)), collapse = ", ")
      )
    )
    
    expect_s3_class(sync$datetime, "POSIXct")
    expect_s3_class(sync$measure_insert_ts, "POSIXct")
    expect_s3_class(sync$measure_update_ts, "POSIXct")
  }
})


test_that("opas_station_log returns expected structure", {
  logs <- opas_station_log(
    station_id = fixture_station_id,
    start = "2026-01-01T00:00:00",
    end   = "2026-02-01T00:00:00",
    auth = auth
  )
  
  expect_s3_class(logs, "tbl_df")
  expect_gt(nrow(logs), 0)
  
  expected_cols <- c(
    "log_id",
    "log_date",
    "log_daily",
    "station_id",
    "station_name",
    "lt_id",
    "lt_name",
    "log_title",
    "log_link",
    "log_obj",
    "log_insert_ts"
  )
  
  expect_true(
    all(expected_cols %in% names(logs)),
    info = paste(
      "Missing columns:",
      paste(setdiff(expected_cols, names(logs)), collapse = ", ")
    )
  )
  
  expect_s3_class(logs$log_date, "POSIXct")
  expect_s3_class(logs$log_insert_ts, "POSIXct")
  expect_true(is.list(logs$log_obj))
})


test_that("lookup endpoints return expected structures", {
  limits <- opas_limits(auth = auth)
  stats <- opas_statistics(auth = auth)
  links <- opas_statistics_limits(auth = auth)
  
  expect_s3_class(limits, "tbl_df")
  expect_s3_class(stats, "tbl_df")
  expect_s3_class(links, "tbl_df")
  
  expect_gt(nrow(limits), 0)
  expect_gt(nrow(stats), 0)
  expect_gt(nrow(links), 0)
  
  expect_true(all(c(
    "limit_id",
    "limit_description",
    "limit_threshold",
    "limit_unit"
  ) %in% names(limits)))
  
  expect_true(all(c(
    "statistic_id",
    "statistic_description"
  ) %in% names(stats)))
  
  expect_true(all(c(
    "stat_poll_id",
    "stat_poll_type",
    "pollutant_id",
    "parameter_id",
    "statistic_id",
    "limit_id"
  ) %in% names(links)))
})


test_that("annual statistics endpoints return expected structure", {
  sr <- opas_get_series_stats(
    series_id = fixture_series_id,
    year = fixture_year,
    auth = auth
  )
  
  st <- opas_get_station_stats(
    station_id = fixture_station_id,
    year = fixture_year,
    auth = auth
  )
  
  expect_s3_class(sr, "tbl_df")
  expect_s3_class(st, "tbl_df")
  
  expect_gt(nrow(sr), 0)
  expect_gt(nrow(st), 0)
  
  expected_cols <- c(
    "series_id",
    "station_id",
    "stat_poll_id",
    "stat_poll_type",
    "result_from",
    "result_to",
    "result_value",
    "result_valid"
  )
  
  expect_true(
    all(expected_cols %in% names(sr)),
    info = paste(
      "Missing series stats columns:",
      paste(setdiff(expected_cols, names(sr)), collapse = ", ")
    )
  )
  
  expect_true(
    all(expected_cols %in% names(st)),
    info = paste(
      "Missing station stats columns:",
      paste(setdiff(expected_cols, names(st)), collapse = ", ")
    )
  )
  
  expect_s3_class(sr$result_from, "Date")
  expect_s3_class(sr$result_to, "Date")
  expect_s3_class(st$result_from, "Date")
  expect_s3_class(st$result_to, "Date")
})
