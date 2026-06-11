test_that("opas_sync_series parses synchro response", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_true(grepl("^series-data-synchro/12900/", path))
      
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
              measure_insert_ts = "2026-06-01T00:02:00.000+00",
              measure_update_ts = "2026-06-01T01:00:00.000+00",
              measure_update_obj = list(
                list(old = 1, new = 0)
              )
            )
          )
        )
      )
    },
    .package = "ropas"
  )
  
  out <- opas_sync_series(12900, since = "2026-06-01T00:00:00")
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_true(all(c(
    "datetime",
    "value_raw",
    "measure_insert_ts",
    "measure_update_ts"
  ) %in% names(out)))
  
  expect_s3_class(out$datetime, "POSIXct")
  expect_s3_class(out$measure_insert_ts, "POSIXct")
  expect_s3_class(out$measure_update_ts, "POSIXct")
})


test_that("opas_sync_series returns empty tibble when no updates are returned", {
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
  
  expect_message(
    out <- opas_sync_series(12900, since = "2026-06-01T00:00:00"),
    "No updates for series"
  )
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0)
})
