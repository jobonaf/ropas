# Tests for authentication state management.
# These tests are fully offline: no OPAS credentials and no HTTP calls.

local_auth_state <- function() {
  old <- list(
    token = .opas_env$token,
    refresh_token = .opas_env$refresh_token,
    expires_at = .opas_env$expires_at
  )
  
  withr::defer({
    .opas_env$token <- old$token
    .opas_env$refresh_token <- old$refresh_token
    .opas_env$expires_at <- old$expires_at
  }, envir = parent.frame())
  
  invisible(old)
}


test_that("opas_login stores authentication state", {
  local_auth_state()
  
  fake_auth <- structure(
    list(
      token = "token_login",
      refresh_token = "refresh_login",
      expires_at = Sys.time() + 3600
    ),
    class = "ropas_auth"
  )
  
  testthat::local_mocked_bindings(
    opas_auth = function(email, password) {
      expect_equal(email, "user@example.org")
      expect_equal(password, "secret")
      fake_auth
    },
    .package = "ropas"
  )
  
  out <- opas_login("user@example.org", "secret")
  
  expect_true(isTRUE(out))
  expect_equal(.opas_env$token, "token_login")
  expect_equal(.opas_env$refresh_token, "refresh_login")
  expect_s3_class(.opas_env$expires_at, "POSIXct")
})


test_that("opas_current_auth returns current internal auth object", {
  local_auth_state()
  
  .opas_env$token <- "token_current"
  .opas_env$refresh_token <- "refresh_current"
  .opas_env$expires_at <- Sys.time() + 3600
  
  auth <- opas_current_auth()
  
  expect_s3_class(auth, "ropas_auth")
  expect_equal(auth$token, "token_current")
  expect_equal(auth$refresh_token, "refresh_current")
  expect_s3_class(auth$expires_at, "POSIXct")
})


test_that("opas_current_auth errors when no token is available", {
  local_auth_state()
  
  .opas_env$token <- NULL
  .opas_env$refresh_token <- NULL
  .opas_env$expires_at <- NULL
  
  expect_error(
    opas_current_auth(),
    "Not logged in"
  )
})


test_that("opas_ensure_token accepts a non-expired token", {
  local_auth_state()
  
  .opas_env$token <- "token_valid"
  .opas_env$refresh_token <- "refresh_valid"
  .opas_env$expires_at <- Sys.time() + 3600
  
  expect_null(opas_ensure_token())
})


test_that("opas_ensure_token accepts token without expiry metadata", {
  local_auth_state()
  
  .opas_env$token <- "token_no_expiry"
  .opas_env$refresh_token <- "refresh_no_expiry"
  .opas_env$expires_at <- NULL
  
  expect_null(opas_ensure_token())
})


test_that("opas_ensure_token errors when not logged in", {
  local_auth_state()
  
  .opas_env$token <- NULL
  .opas_env$refresh_token <- NULL
  .opas_env$expires_at <- NULL
  
  expect_error(
    opas_ensure_token(),
    "Not logged in"
  )
})


test_that("opas_ensure_token refreshes an expired token", {
  local_auth_state()
  
  .opas_env$token <- "token_old"
  .opas_env$refresh_token <- "refresh_old"
  .opas_env$expires_at <- Sys.time() - 10
  
  called <- FALSE
  
  testthat::local_mocked_bindings(
    opas_refresh = function() {
      called <<- TRUE
      .opas_env$token <- "token_new"
      .opas_env$expires_at <- Sys.time() + 3600
      invisible(TRUE)
    },
    .package = "ropas"
  )
  
  expect_null(opas_ensure_token())
  expect_true(called)
  expect_equal(.opas_env$token, "token_new")
})


test_that("opas_ensure_token wraps refresh errors", {
  local_auth_state()
  
  .opas_env$token <- "token_old"
  .opas_env$refresh_token <- "refresh_old"
  .opas_env$expires_at <- Sys.time() - 10
  
  testthat::local_mocked_bindings(
    opas_refresh = function() {
      rlang::abort("refresh failed internally")
    },
    .package = "ropas"
  )
  
  expect_error(
    opas_ensure_token(),
    "Automatic token refresh failed"
  )
})


test_that("opas_refresh errors when no refresh token is available", {
  local_auth_state()
  
  .opas_env$token <- "token"
  .opas_env$refresh_token <- NULL
  .opas_env$expires_at <- Sys.time() - 10
  
  expect_error(
    opas_refresh(),
    "No refresh token available"
  )
})


test_that("opas_logout clears local authentication state when no token is set", {
  local_auth_state()
  
  # Keep token NULL so opas_logout() skips the server-side httr2 request.
  .opas_env$token <- NULL
  .opas_env$refresh_token <- "refresh_to_clear"
  .opas_env$expires_at <- Sys.time() + 3600
  
  out <- opas_logout()
  
  expect_true(isTRUE(out))
  expect_null(.opas_env$token)
  expect_null(.opas_env$refresh_token)
  expect_null(.opas_env$expires_at)
})


test_that("opas_logout clears local authentication state when server logout fails", {
  local_auth_state()
  
  .opas_env$token <- "token_to_logout"
  .opas_env$refresh_token <- "refresh_to_logout"
  .opas_env$expires_at <- Sys.time() + 3600
  
  testthat::local_mocked_bindings(
    # opas_logout() builds a request and then calls httr2::req_perform().
    # Mock only req_perform() so the function exercises its local cleanup path
    # without making a real HTTP request.
    .package = "httr2",
    req_perform = function(req) {
      rlang::abort("mock logout failure")
    }
  )
  
  out <- opas_logout()
  
  expect_true(isTRUE(out))
  expect_null(.opas_env$token)
  expect_null(.opas_env$refresh_token)
  expect_null(.opas_env$expires_at)
})
