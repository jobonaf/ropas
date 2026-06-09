test_that(".opas_to_epoch parses POSIXct and ISO strings", {
  x <- as.POSIXct("2026-06-01 00:00:00", tz = "Etc/GMT-1")
  
  expect_type(.opas_to_epoch(x), "integer")
  expect_type(.opas_to_epoch("2026-06-01T00:00:00"), "integer")
  expect_true(is.na(.opas_to_epoch("not-a-date")))
})

test_that(".opas_parse_datetime_column ignores missing columns", {
  df <- tibble::tibble(x = 1)
  
  out <- .opas_parse_datetime_column(
    df,
    col = "missing",
    tz = "UTC"
  )
  
  expect_identical(out, df)
})

test_that(".opas_parse_synchro handles missing optional timestamp columns", {
  series_data <- list(
    list(
      measure_date_time = "2026-06-01T00:00:00",
      measure_value = 10,
      post_validity_code = 0
    )
  )
  
  context <- list(
    series_id = 1L,
    station_id = 10L,
    station_name = "Station",
    parameter_name = "O3",
    parameter_unit = "ppb"
  )
  
  out <- .opas_parse_synchro(series_data, context)
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_true("datetime" %in% names(out))
  expect_true("value_raw" %in% names(out))
  expect_false("measure_value" %in% names(out))
})

test_that(".opas_sync_key avoids series_NA names", {
  key <- .opas_sync_key(
    series_id = NA_integer_,
    station_id = 123,
    index = 5,
    regional = FALSE
  )
  
  expect_equal(key, "series_missing_5")
  
  key_region <- .opas_sync_key(
    series_id = NA_integer_,
    station_id = 123,
    index = 5,
    regional = TRUE
  )
  
  expect_equal(key_region, "station_123_series_missing_5")
})

test_that(".opas_add_sync_result appends duplicate keys", {
  result <- list(
    series_1 = tibble::tibble(x = 1)
  )
  
  expect_warning(
    out <- .opas_add_sync_result(
      result = result,
      key = "series_1",
      value = tibble::tibble(x = 2)
    ),
    "Duplicate synchro key"
  )
  
  expect_equal(nrow(out$series_1), 2)
  expect_equal(out$series_1$x, c(1, 2))
})
