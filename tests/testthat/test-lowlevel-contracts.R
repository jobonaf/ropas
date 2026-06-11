test_that("opas_sites parses sites and renames id/name", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_equal(path, "sites")
      
      list(
        sites = list(
          list(
            id = 1L,
            name = "Site A",
            network_names = list(c("Network 1", "Network 2")),
            municipality_name = "Comune",
            province_name = "Provincia",
            region_name = "Regione",
            locality = "Località",
            altitude = 100L,
            wgs84_lat = 45.1,
            wgs84_lon = 13.1,
            note = "note"
          )
        )
      )
    },
    .package = "ropas"
  )
  
  out <- opas_sites()
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_true(all(c("site_id", "site_name") %in% names(out)))
  expect_false("id" %in% names(out))
  expect_false("name" %in% names(out))
  expect_equal(out$site_id, 1L)
  expect_equal(out$site_name, "Site A")
  expect_true(is.list(out$network_names))
})


test_that("opas_sites returns empty tibble on empty sites list", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      list(sites = list())
    },
    .package = "ropas"
  )
  
  expect_warning(
    out <- opas_sites(),
    "empty `sites` table"
  )
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0)
})


test_that("opas_campaigns treats allocations NULL as no data", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_equal(path, "campaigns/1167")
      list(allocations = NULL)
    },
    .package = "ropas"
  )
  
  expect_warning(
    out <- opas_campaigns(1167),
    "no campaign allocations"
  )
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0)
})


test_that("opas_campaigns parses non-empty allocations and datetimes", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_equal(path, "campaigns/1135")
      
      list(
        allocations = list(
          list(
            station_id = 1135L,
            station_name = "MM-TS (TS)",
            station_override_id = 1486L,
            station_external_id = "257",
            site_id = 21L,
            site_name = "Site name",
            network_names = list(c("Network")),
            site_locality = "Locality",
            site_wgs84_lat = 45.1,
            site_wgs84_lon = 13.1,
            allocation_startup_date = "2026-01-01T00:00:00",
            allocation_dismiss_date = "2026-02-01T00:00:00"
          )
        )
      )
    },
    .package = "ropas"
  )
  
  out <- opas_campaigns(1135)
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_true(all(c(
    "station_id",
    "station_name",
    "site_id",
    "site_name",
    "allocation_startup_date",
    "allocation_dismiss_date"
  ) %in% names(out)))
  
  expect_s3_class(out$allocation_startup_date, "POSIXct")
  expect_s3_class(out$allocation_dismiss_date, "POSIXct")
})


test_that("opas_campaigns builds ISO path when at is supplied", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_equal(path, "campaigns/1167/2026-06-01T00:00:00")
      list(allocations = NULL)
    },
    .package = "ropas"
  )
  
  expect_warning(
    out <- opas_campaigns(1167, at = "2026-06-01T00:00:00"),
    "no campaign allocations"
  )
  
  expect_s3_class(out, "tbl_df")
})


test_that("opas_station_parameters parses station and parameter details", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_equal(path, "stations-parameters/1167/34")
      
      list(
        station = list(
          id = 1167L,
          name = "Ugovizza - via Stazione",
          external_id = "227",
          export_id = "227",
          parameters = list(
            list(
              series_id = 3041L,
              series_name = "O3",
              database_id = 7L,
              id = 34L,
              external_id = "O3-ext",
              export_id1 = "O3-export-1",
              export_id2 = "O3-export-2",
              name = "O3",
              unit = "ppb",
              conversion_factor_curr = 2,
              conversion_history = list(
                list(
                  date_from = "-infinity",
                  date_to = "infinity",
                  value = 2
                )
              ),
              conversion_unit = "µg/m³",
              decimals = 1L,
              active = TRUE,
              note = NA_character_
            )
          )
        )
      )
    },
    .package = "ropas"
  )
  
  out <- opas_station_parameters(1167, 34)
  
  expect_type(out, "list")
  expect_true(all(c("station", "parameters") %in% names(out)))
  
  expect_s3_class(out$station, "tbl_df")
  expect_s3_class(out$parameters, "tbl_df")
  
  expect_equal(nrow(out$station), 1)
  expect_equal(nrow(out$parameters), 1)
  
  expect_true(all(c("station_id", "station_name") %in% names(out$station)))
  
  expected_param_cols <- c(
    "series_id",
    "parameter_id",
    "parameter_external_id",
    "parameter_name",
    "parameter_unit",
    "parameter_conv_curr",
    "parameter_conv_unit",
    "conversion_history"
  )
  
  expect_true(
    all(expected_param_cols %in% names(out$parameters)),
    info = paste(
      "Missing columns:",
      paste(setdiff(expected_param_cols, names(out$parameters)), collapse = ", ")
    )
  )
  
  expect_equal(out$station$station_id[[1]], 1167L)
  expect_equal(out$parameters$parameter_id[[1]], 34L)
  expect_equal(out$parameters$parameter_external_id[[1]], "O3-ext")
  expect_equal(out$parameters$parameter_name[[1]], "O3")
  expect_equal(out$parameters$parameter_unit[[1]], "ppb")
  expect_equal(out$parameters$parameter_conv_curr[[1]], 2)
  expect_equal(out$parameters$parameter_conv_unit[[1]], "µg/m³")
  expect_true(is.list(out$parameters$conversion_history))
})

test_that("opas_station_log builds ISO path and parses timestamps", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      expect_equal(
        path,
        "stations-log/1167/2026-01-01T00:00:00/2026-02-01T00:00:00"
      )
      
      list(
        stations = list(
          list(
            log_id = 1L,
            log_date = "2026-01-15T12:00:00",
            log_daily = FALSE,
            station_id = 1167L,
            station_name = "Ugovizza - via Stazione",
            lt_id = 2L,
            lt_name = "Maintenance",
            log_creator_fullname = "User",
            log_title = "Title",
            log_link = "https://example.org",
            log_obj = list(
              list(
                desc = "Description",
                title = "Title"
              )
            ),
            log_note = "Note",
            log_note_creator_fullname = "User",
            log_insert_ts = "2026-01-15T12:30:00.000+00"
          )
        )
      )
    },
    .package = "ropas"
  )
  
  out <- opas_station_log(
    station_id = 1167,
    start = "2026-01-01T00:00:00",
    end   = "2026-02-01T00:00:00"
  )
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  
  expect_true(all(c(
    "log_id",
    "log_date",
    "station_id",
    "station_name",
    "log_insert_ts",
    "log_obj"
  ) %in% names(out)))
  
  expect_equal(out$log_id[[1]], 1L)
  expect_equal(out$station_id[[1]], 1167L)
  
  expect_s3_class(out$log_date, "POSIXct")
  expect_s3_class(out$log_insert_ts, "POSIXct")
  expect_true(is.list(out$log_obj))
})

test_that("opas_station_log returns empty tibble on empty stations list", {
  testthat::local_mocked_bindings(
    opas_request = function(path, ...) {
      list(stations = list())
    },
    .package = "ropas"
  )
  
  expect_warning(
    out <- opas_station_log(
      station_id = 1167,
      start = "2026-01-01T00:00:00",
      end   = "2026-02-01T00:00:00"
    ),
    "empty `stations` table"
  )
  
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0)
})