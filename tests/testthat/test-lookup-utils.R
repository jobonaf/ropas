test_that(".opas_parse_lookup_table handles missing, empty and non-empty tables", {
  expect_error(
    .opas_parse_lookup_table(NULL, "limits"),
    "missing `limits` field"
  )
  
  expect_warning(
    empty <- .opas_parse_lookup_table(list(), "limits"),
    "empty `limits` table"
  )
  
  expect_s3_class(empty, "tbl_df")
  expect_equal(nrow(empty), 0)
  
  out <- .opas_parse_lookup_table(
    list(
      list(limit_id = 1L, limit_description = "A"),
      list(limit_id = 2L, limit_description = "B")
    ),
    "limits"
  )
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 2)
  expect_true(all(c("limit_id", "limit_description") %in% names(out)))
})