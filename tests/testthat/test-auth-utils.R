test_that(".opas_jwt_exp returns NULL for invalid tokens", {
  expect_null(.opas_jwt_exp(NULL))
  expect_null(.opas_jwt_exp(""))
  expect_null(.opas_jwt_exp(NA_character_))
  expect_null(.opas_jwt_exp("not-a-jwt"))
  expect_null(.opas_jwt_exp("a.b"))
})

test_that(".opas_resolve_expires_at uses body exp when JWT parsing fails", {
  exp <- as.integer(as.POSIXct("2026-01-01 00:00:00", tz = "UTC"))
  
  expect_warning(
    out <- .opas_resolve_expires_at(token = "not-a-jwt", exp = exp),
    "Could not parse JWT expiry"
  )
  
  expect_s3_class(out, "POSIXct")
  expect_equal(
    as.integer(out),
    exp
  )
})

test_that(".opas_resolve_expires_at falls back with warnings", {
  warnings <- character()
  
  out <- withCallingHandlers(
    .opas_resolve_expires_at(
      token = "not-a-jwt",
      exp = NULL,
      fallback_seconds = 10
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  
  expect_s3_class(out, "POSIXct")
  expect_true(out > Sys.time())
  
  expect_true(any(grepl("Could not parse JWT expiry", warnings)))
  expect_true(any(grepl("Could not determine token expiry", warnings)))
})