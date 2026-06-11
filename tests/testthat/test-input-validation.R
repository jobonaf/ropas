test_that("opas_get_data validates retrieval mode", {
  expect_error(
    opas_get_data(1),
    "Provide one of"
  )
  
  expect_error(
    opas_get_data(1, last_hours = 24, last_days = 7),
    "Supply exactly one retrieval mode"
  )
  
  expect_error(
    opas_get_data(1, last_hours = 24, start = "2026-01-01T00:00:00"),
    "Supply exactly one retrieval mode"
  )
  
  expect_error(
    opas_get_data(1, start = "2026-01-01T00:00:00"),
    "`start` and `end` must be supplied together"
  )
  
  expect_error(
    opas_get_data(1, end = "2026-01-01T00:00:00"),
    "`start` and `end` must be supplied together"
  )
})


test_that("opas_get_data validates numeric inputs", {
  expect_error(
    opas_get_data("abc", last_hours = 24),
    "`series_id` must be numeric"
  )
  
  expect_error(
    opas_get_data(1, last_hours = "abc"),
    "`last_hours` must be a positive integer"
  )
  
  expect_error(
    opas_get_data(1, last_hours = 0),
    "`last_hours` must be a positive integer"
  )
  
  expect_error(
    opas_get_data(1, last_hours = -1),
    "`last_hours` must be a positive integer"
  )
  
  expect_error(
    opas_get_data(1, last_days = "abc"),
    "`last_days` must be a positive integer"
  )
  
  expect_error(
    opas_get_data(1, last_days = 0),
    "`last_days` must be a positive integer"
  )
  
  expect_error(
    opas_get_data(1, last_days = -1),
    "`last_days` must be a positive integer"
  )
})


test_that("opas_get_data validates date ranges before request", {
  expect_error(
    opas_get_data(
      1,
      start = "not-a-date",
      end   = "2026-01-02T00:00:00"
    ),
    "`start` and `end` must be POSIXct or ISO 8601 strings"
  )
  
  expect_error(
    opas_get_data(
      1,
      start = "2026-01-02T00:00:00",
      end   = "2026-01-01T00:00:00"
    ),
    "`start` must be earlier than `end`"
  )
})


test_that("opas_series validates region and station before request", {
  expect_error(
    opas_series(region = "99"),
    "ISTAT code"
  )
  
  expect_error(
    opas_series(region = "foo"),
    "ISTAT code"
  )
  
  expect_error(
    opas_series(region = "06", station = 1),
    "Provide only one"
  )
  
  expect_error(
    opas_series(station = "abc"),
    "`station` must be numeric"
  )
})


test_that("opas_stations validates region before request", {
  expect_error(
    opas_stations(region = "99"),
    "ISTAT code"
  )
  
  expect_error(
    opas_stations(region = "foo"),
    "ISTAT code"
  )
})


test_that("single metadata endpoints validate ids before request", {
  expect_error(
    opas_station("abc"),
    "`station_id` must be numeric"
  )
  
  expect_error(
    opas_parameter("abc"),
    "`parameter_id` must be numeric"
  )
})


test_that("statistics functions validate inputs before request", {
  expect_error(
    opas_get_station_stats("abc", 2025),
    "`station_id` must be numeric"
  )
  
  expect_error(
    opas_get_series_stats("abc", 2025),
    "`series_id` must be numeric"
  )
  
  expect_error(
    opas_get_station_stats(1, "abc"),
    "four-digit integer"
  )
  
  expect_error(
    opas_get_series_stats(1, "abc"),
    "four-digit integer"
  )
  
  current_year <- as.integer(format(Sys.Date(), "%Y"))
  
  expect_error(
    opas_get_station_stats(1, current_year),
    "completed years"
  )
  
  expect_error(
    opas_get_series_stats(1, current_year),
    "completed years"
  )
})


test_that("synchro functions validate ids and since before request", {
  expect_error(
    opas_sync_series("abc", since = "2026-06-01T00:00:00"),
    "`series_id` must be numeric"
  )
  
  expect_error(
    opas_sync_series(1, since = "not-a-date"),
    "`since` must be a POSIXct or ISO 8601 string"
  )
  
  expect_error(
    opas_sync_station("abc", since = "2026-06-01T00:00:00"),
    "`station_id` must be numeric"
  )
  
  expect_error(
    opas_sync_station(1, since = "not-a-date"),
    "`since` must be a POSIXct or ISO 8601 string"
  )
  
  expect_error(
    opas_sync_region("foo", since = "2026-06-01T00:00:00"),
    "ISTAT code"
  )
  
  expect_error(
    opas_sync_region("99", since = "2026-06-01T00:00:00"),
    "ISTAT code"
  )
  
  expect_error(
    opas_sync_region("06", since = "not-a-date"),
    "`since` must be a POSIXct or ISO 8601 string"
  )
})


test_that("opas_request validates path and query before auth/request", {
  expect_error(
    opas_request(""),
    "`path` must be a non-empty character scalar"
  )
  
  expect_error(
    opas_request(letters[1:2]),
    "`path` must be a non-empty character scalar"
  )
  
  expect_error(
    opas_request("/series/06"),
    "`path` must not start with a leading slash"
  )
  
  expect_error(
    opas_request("series/06", query = "not-a-list"),
    "`query` must be a named list"
  )
  
  expect_error(
    opas_request("series/06", query = list(1, a = 2)),
    "`query` must be a fully named list"
  )
})

test_that("new metadata endpoints validate input before request", {
  expect_error(
    opas_campaigns("abc"),
    "`station_id` must be numeric"
  )
  
  expect_error(
    opas_campaigns(1167, at = "not-a-date"),
    "`at` must be a POSIXct or ISO 8601 string"
  )
  
  expect_error(
    opas_station_parameters("abc", 34),
    "`station_id` must be numeric"
  )
  
  expect_error(
    opas_station_parameters(1167, "abc"),
    "`parameter_id` must be numeric"
  )
})


test_that("opas_station_log validates input before request", {
  expect_error(
    opas_station_log(
      station_id = "abc",
      start = "2026-01-01T00:00:00",
      end   = "2026-02-01T00:00:00"
    ),
    "`station_id` must be numeric"
  )
  
  expect_error(
    opas_station_log(
      station_id = 1167,
      start = "not-a-date",
      end   = "2026-02-01T00:00:00"
    ),
    "`start` must be a POSIXct or ISO 8601 string"
  )
  
  expect_error(
    opas_station_log(
      station_id = 1167,
      start = "2026-02-01T00:00:00",
      end   = "2026-01-01T00:00:00"
    ),
    "`start` must be earlier than `end`"
  )
})