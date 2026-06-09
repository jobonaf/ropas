test_that(".opas_validate_stats_year validates completed years", {
  expect_equal(.opas_validate_stats_year("2025"), 2025L)
  expect_equal(.opas_validate_stats_year(2025), 2025L)
  
  expect_error(
    .opas_validate_stats_year("abc"),
    "four-digit integer"
  )
  
  expect_error(
    .opas_validate_stats_year(as.integer(format(Sys.Date(), "%Y"))),
    "completed years"
  )
})

test_that(".opas_parse_date_column parses existing date columns", {
  df <- tibble::tibble(
    result_from = c("2025-01-01", "2025-02-01"),
    x = 1:2
  )
  
  out <- .opas_parse_date_column(df, "result_from")
  
  expect_s3_class(out$result_from, "Date")
  expect_equal(out$x, 1:2)
})

test_that(".opas_parse_date_column ignores missing columns", {
  df <- tibble::tibble(x = 1:2)
  
  out <- .opas_parse_date_column(df, "result_from")
  
  expect_identical(out, df)
})

test_that(".opas_parse_statistics_results returns empty tibble for empty input", {
  out <- .opas_parse_statistics_results(list())
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0)
})

test_that(".opas_parse_statistics_results parses result dates when present", {
  stats <- list(
    list(result_from = "2025-01-01", result_to = "2025-12-31", value = 1),
    list(result_from = "2025-01-01", result_to = "2025-12-31", value = 2)
  )
  
  out <- .opas_parse_statistics_results(stats)
  
  expect_s3_class(out$result_from, "Date")
  expect_s3_class(out$result_to, "Date")
  expect_equal(nrow(out), 2)
})