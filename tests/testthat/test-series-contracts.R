test_that("opas_series parses region response", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_equal(path, "series/06")
      
      list(
        series = list(
          list(
            series_id = 123L,
            series_name = "O3",
            station_id = 1167L,
            station_name = "Station",
            parameter_id = 34L,
            parameter_name = "O3",
            parameter_unit = "ppb",
            parameter_conv_curr = 2,
            conversion_unit = "µg/m³",
            region_istat_code = "06",
            region_name = "Friuli-Venezia Giulia"
          )
        )
      )
    },
    .package = "ropas"
  )
  
  out <- opas_series(region = "6")
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_equal(out$series_id[[1]], 123L)
  expect_equal(out$parameter_conv_unit[[1]], "µg/m³")
})


test_that("opas_series parses station response", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_equal(path, "series/1167")
      
      list(
        series = list(
          list(
            series_id = 3041L,
            station_id = 1167L,
            station_name = "Ugovizza - via Stazione",
            parameter_id = 34L,
            parameter_name = "O3",
            parameter_unit = "ppb",
            parameter_conv_curr = 2,
            conversion_unit = "µg/m³"
          )
        )
      )
    },
    .package = "ropas"
  )
  
  out <- opas_series(station = 1167)
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_equal(out$station_id[[1]], 1167L)
  expect_equal(out$parameter_conv_unit[[1]], "µg/m³")
})


test_that("opas_series returns empty tibble when API returns empty series", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      list(series = list())
    },
    .package = "ropas"
  )
  
  out <- opas_series(region = "06")
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0)
})