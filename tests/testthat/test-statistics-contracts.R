test_that("opas_get_series_stats parses statistics results", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_equal(path, "statistics-series-data/Y/12900/2025")
      
      list(
        statistics_results = list(
          list(
            series_id = 12900L,
            station_id = 1173L,
            stat_poll_id = 1L,
            stat_poll_type = "Y",
            limit_id = 10L,
            result_from = "2025-01-01",
            result_to = "2025-12-31",
            result_value = 100,
            result_valid = TRUE
          )
        )
      )
    },
    .package = "ropas"
  )
  
  out <- opas_get_series_stats(12900, 2025)
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_s3_class(out$result_from, "Date")
  expect_s3_class(out$result_to, "Date")
})


test_that("opas_get_station_stats parses statistics results", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_equal(path, "statistics-station-data/Y/1167/2025")
      
      list(
        statistics_results = list(
          list(
            series_id = 3041L,
            station_id = 1167L,
            parameter_id = 34L,
            stat_poll_id = 1L,
            stat_poll_type = "Y",
            result_from = "2025-01-01",
            result_to = "2025-12-31",
            result_value = 80,
            result_valid = TRUE
          )
        )
      )
    },
    .package = "ropas"
  )
  
  out <- opas_get_station_stats(1167, 2025)
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_s3_class(out$result_from, "Date")
  expect_s3_class(out$result_to, "Date")
})


test_that("statistics endpoints return empty tibble when no results are returned", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      list(statistics_results = list())
    },
    .package = "ropas"
  )
  
  expect_warning(
    out <- opas_get_series_stats(12900, 2025),
    "no statistics"
  )
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0)
})
