test_that("opas_get_data parses hourly data response", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_equal(path, "series-data/12900/24")
      
      list(
        data = list(
          series_id = 7L,
          station_id = 1173L,
          station_name = "Brugnera - via Villa Varda",
          parameter_name = "O3",
          parameter_unit = "ppb",
          series_data = list(
            list(
              measure_date_time = "2026-06-01T00:00:00",
              measure_value = 42.5,
              post_validity_code = 0,
              auto_validity_code = 0,
              final_validity_code = 1,
              measure_code = 0
            )
          )
        )
      )
    },
    .package = "ropas"
  )
  
  out <- opas_get_data(12900, last_hours = 24)
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  
  expect_true(all(c(
    "series_id",
    "station_id",
    "station_name",
    "parameter_name",
    "parameter_unit",
    "datetime",
    "value_raw",
    "post_validity_code"
  ) %in% names(out)))
  
  expect_equal(out$value_raw[[1]], 42.5)
  expect_s3_class(out$datetime, "POSIXct")
  expect_false("measure_value" %in% names(out))
  expect_false("measure_date_time" %in% names(out))
})


test_that("opas_get_data parses daily data response", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_equal(path, "series-data-dd/12900/7")
      
      list(
        data = list(
          series_id = 7L,
          station_id = 1173L,
          station_name = "Brugnera - via Villa Varda",
          parameter_name = "O3",
          parameter_unit = "ppb",
          series_data = list(
            list(
              measure_date_time = "2026-06-01T00:00:00",
              measure_value = 50,
              post_validity_code = 0
            )
          )
        )
      )
    },
    .package = "ropas"
  )
  
  out <- opas_get_data(12900, last_days = 7)
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_equal(out$value_raw[[1]], 50)
  expect_s3_class(out$datetime, "POSIXct")
})


test_that("opas_get_data returns empty tibble when no measurements are returned", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      list(
        data = list(
          series_id = 7L,
          station_id = 1173L,
          station_name = "Station",
          parameter_name = "O3",
          parameter_unit = "ppb",
          series_data = list()
        )
      )
    },
    .package = "ropas"
  )
  
  expect_warning(
    out <- opas_get_data(12900, last_hours = 24),
    "no measurements"
  )
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0)
})