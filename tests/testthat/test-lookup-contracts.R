test_that("lookup endpoints parse expected tables", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      switch(
        path,
        limits = list(
          limits = list(
            list(
              limit_id = 1L,
              limit_description = "Limit",
              limit_threshold = 40,
              limit_exceedances = NA_integer_,
              limit_unit = "µg/m³"
            )
          )
        ),
        statistics = list(
          statistics = list(
            list(
              statistic_id = 1L,
              statistic_description = "Media",
              statistic_active = TRUE,
              statistic_order = 1L
            )
          )
        ),
        `statistics-limits` = list(
          statistic_limits = list(
            list(
              stat_poll_id = 1L,
              stat_poll_type = "Y",
              stat_poll_active = TRUE,
              pollutant_id = 34L,
              parameter_id = 34L,
              pollutant_name = "O3",
              statistic_id = 1L,
              statistic_description = "Media",
              statistic_active = TRUE,
              limit_id = 1L,
              limit_from = "-infinity",
              limit_to = "infinity",
              limit_description = "Limit",
              limit_threshold = 120,
              limit_exceedances = NA_integer_,
              limit_unit = "µg/m³"
            )
          )
        ),
        rlang::abort(paste0("Unexpected mocked path: ", path))
      )
    },
    .package = "ropas"
  )
  
  lim <- opas_limits()
  stat <- opas_statistics()
  sl <- opas_statistics_limits()
  
  expect_s3_class(lim, "tbl_df")
  expect_s3_class(stat, "tbl_df")
  expect_s3_class(sl, "tbl_df")
  
  expect_equal(nrow(lim), 1)
  expect_equal(nrow(stat), 1)
  expect_equal(nrow(sl), 1)
  
  expect_true(all(c(
    "limit_id",
    "limit_description",
    "limit_threshold",
    "limit_unit"
  ) %in% names(lim)))
  
  expect_true(all(c(
    "statistic_id",
    "statistic_description",
    "statistic_active",
    "statistic_order"
  ) %in% names(stat)))
  
  expect_true(all(c(
    "stat_poll_id",
    "stat_poll_type",
    "pollutant_id",
    "parameter_id",
    "statistic_id",
    "limit_id",
    "limit_from",
    "limit_to"
  ) %in% names(sl)))
})

test_that("lookup endpoints return empty tibble on empty reference tables", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      switch(
        path,
        limits = list(limits = list()),
        statistics = list(statistics = list()),
        `statistics-limits` = list(statistic_limits = list()),
        rlang::abort(paste0("Unexpected mocked path: ", path))
      )
    },
    .package = "ropas"
  )
  
  expect_warning(
    lim <- opas_limits(),
    "empty `limits` table"
  )
  
  expect_warning(
    stat <- opas_statistics(),
    "empty `statistics` table"
  )
  
  expect_warning(
    sl <- opas_statistics_limits(),
    "empty `statistic_limits` table"
  )
  
  expect_s3_class(lim, "tbl_df")
  expect_s3_class(stat, "tbl_df")
  expect_s3_class(sl, "tbl_df")
  
  expect_equal(nrow(lim), 0)
  expect_equal(nrow(stat), 0)
  expect_equal(nrow(sl), 0)
})