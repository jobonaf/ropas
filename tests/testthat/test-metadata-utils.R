test_that(".opas_normalize_region pads valid region codes", {
  expect_equal(.opas_normalize_region(6), "06")
  expect_equal(.opas_normalize_region("6"), "06")
  expect_equal(.opas_normalize_region("06"), "06")
})

test_that(".opas_normalize_region rejects invalid region codes", {
  expect_error(.opas_normalize_region("foo"), "ISTAT code")
  expect_error(.opas_normalize_region("99"), "ISTAT code")
  expect_error(.opas_normalize_region(NA), "ISTAT code")
})

test_that(".opas_rename_cols renames existing columns and ignores missing ones", {
  df <- tibble::tibble(
    id = 1,
    name = "Station",
    other = "x"
  )
  
  out <- .opas_rename_cols(
    df,
    c(
      station_id = "id",
      station_name = "name",
      missing_new = "missing_old"
    )
  )
  
  expect_true(all(c("station_id", "station_name", "other") %in% names(out)))
  expect_false("id" %in% names(out))
  expect_false("name" %in% names(out))
  expect_false("missing_new" %in% names(out))
})

test_that(".opas_one_row_tibble preserves nested fields as list-columns", {
  x <- list(
    id = 1,
    name = "Station",
    coords = c(13.1, 45.9),
    nested = list(a = 1, b = 2),
    empty = NULL
  )
  
  out <- .opas_one_row_tibble(x)
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_equal(out$id, 1)
  expect_equal(out$name, "Station")
  expect_true(is.list(out$coords))
  expect_true(is.list(out$nested))
  expect_true(is.list(out$empty))
})

test_that(".opas_datetime_to_iso parses POSIXct and ISO strings", {
  x <- as.POSIXct("2026-06-01 00:00:00", tz = "Etc/GMT-1")
  
  expect_equal(
    .opas_datetime_to_iso(x, arg = "at"),
    "2026-06-01T00:00:00"
  )
  
  expect_equal(
    .opas_datetime_to_iso("2026-06-01T00:00:00", arg = "at"),
    "2026-06-01T00:00:00"
  )
  
  expect_error(
    .opas_datetime_to_iso("not-a-date", arg = "at"),
    "`at` must be a POSIXct or ISO 8601 string"
  )
})