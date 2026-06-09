#' Create an OPAS authentication object
#'
#' Authenticates with the OPAS web service and returns an authentication
#' object containing the access token, refresh token, and expiry time.
#'
#' Unlike \code{\link{opas_login}}, this function does not modify the
#' package internal authentication state. It is useful for advanced
#' workflows, especially process-based parallel execution, where worker
#' processes should receive authentication explicitly rather than relying
#' on the package-global authentication environment.
#'
#' @param email Email address registered on the OPAS portal.
#' @param password Corresponding password.
#'
#' @return An object of class \code{"ropas_auth"} containing:
#'   \describe{
#'     \item{token}{JWT access token.}
#'     \item{refresh_token}{Refresh token returned by OPAS.}
#'     \item{expires_at}{Token expiry time as \code{POSIXct} in UTC.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' auth <- opas_auth("my@email.it", "my_password")
#' }
opas_auth <- function(email, password) {
  
  req <- httr2::request(.opas_env$base_url) |>
    httr2::req_url_path_append("login") |>
    httr2::req_method("POST") |>
    httr2::req_body_json(list(
      email    = email,
      password = password
    ))
  
  resp <- httr2::req_perform(req)
  
  if (httr2::resp_status(resp) != 200L) {
    rlang::abort(
      paste0(
        "Login failed (HTTP ", httr2::resp_status(resp), "). ",
        "Check credentials."
      ),
      class = "opas_auth_error"
    )
  }
  
  data <- httr2::resp_body_json(resp)
  
  if (is.null(data$token)) {
    rlang::abort(
      "Login response did not contain a token.",
      class = "opas_auth_error"
    )
  }
  
  if (is.null(data$refreshToken)) {
    rlang::abort(
      "Login response did not contain a refresh token.",
      class = "opas_auth_error"
    )
  }
  
  expires_at <- .opas_resolve_expires_at(
    token = data$token,
    exp   = data$exp
  )
  
  structure(
    list(
      token         = data$token,
      refresh_token = data$refreshToken,
      expires_at    = expires_at
    ),
    class = "ropas_auth"
  )
}


#' Login to OPAS API
#'
#' Authenticates with the OPAS web service and stores the JWT access token
#' and refresh token internally. Must be called before any other API
#' function when using the default interactive authentication workflow.
#'
#' The token is valid for approximately 1 hour; subsequent calls are handled
#' automatically by \code{opas_ensure_token()}.
#'
#' For parallel workflows, prefer \code{\link{opas_auth}} and pass the
#' returned object explicitly to API functions that support an \code{auth}
#' argument.
#'
#' @param email Email address registered on the OPAS portal.
#' @param password Corresponding password.
#'
#' @return Invisibly returns \code{TRUE} on success.
#' @export
#'
#' @examples
#' \dontrun{
#' opas_login("user@arpa.fvg.it", "my_password")
#' }
opas_login <- function(email, password) {
  
  auth <- opas_auth(email, password)
  
  .opas_env$token         <- auth$token
  .opas_env$refresh_token <- auth$refresh_token
  .opas_env$expires_at    <- auth$expires_at
  
  invisible(TRUE)
}


#' Get current OPAS authentication object
#'
#' Returns the currently stored authentication state as an object of class
#' \code{"ropas_auth"}.
#'
#' This is mainly useful for advanced workflows, including process-based
#' parallel execution, where the current token needs to be passed explicitly
#' to worker processes.
#'
#' @return An object of class \code{"ropas_auth"}.
#' @export
#'
#' @examples
#' \dontrun{
#' opas_login("user@arpa.fvg.it", "my_password")
#' auth <- opas_current_auth()
#' }
opas_current_auth <- function() {
  
  opas_ensure_token()
  
  structure(
    list(
      token         = .opas_env$token,
      refresh_token = .opas_env$refresh_token,
      expires_at    = .opas_env$expires_at
    ),
    class = "ropas_auth"
  )
}


#' Refresh the OPAS access token
#'
#' Uses the stored refresh token to obtain a new access token from
#' \code{POST /refresh-token}. Called automatically by
#' \code{opas_ensure_token()}; users should not normally need to call this
#' directly.
#'
#' The \code{/refresh-token} endpoint returns only a new \code{token}; the
#' refresh token itself is not rotated, so \code{.opas_env$refresh_token}
#' is left unchanged.
#'
#' @return Invisibly returns \code{TRUE} on success.
#'
#' @noRd
opas_refresh <- function() {
  
  if (is.null(.opas_env$refresh_token)) {
    rlang::abort(
      "No refresh token available. Please call opas_login() again.",
      class = "opas_auth_error"
    )
  }
  
  req <- httr2::request(.opas_env$base_url) |>
    httr2::req_url_path_append("refresh-token") |>
    httr2::req_method("POST") |>
    httr2::req_body_json(list(
      refreshToken = .opas_env$refresh_token
    ))
  
  resp <- httr2::req_perform(req)
  
  if (httr2::resp_status(resp) != 200L) {
    rlang::abort(
      paste0(
        "Token refresh failed (HTTP ", httr2::resp_status(resp), "). ",
        "Please call opas_login() again."
      ),
      class = "opas_auth_error"
    )
  }
  
  data <- httr2::resp_body_json(resp)
  
  if (is.null(data$token)) {
    rlang::abort(
      "Refresh response did not contain a token.",
      class = "opas_auth_error"
    )
  }
  
  new_token <- data$token
  
  new_expires_at <- .opas_resolve_expires_at(
    token = new_token
  )
  
  .opas_env$token      <- new_token
  .opas_env$expires_at <- new_expires_at
  
  # .opas_env$refresh_token is intentionally NOT updated:
  # /refresh-token does not return a rotated refresh token.
  
  invisible(TRUE)
}


#' Ensure a valid OPAS token is available
#'
#' Checks that the user is logged in and that the current token has not
#' expired, using a 60-second safety margin. If the token is close to
#' expiry, \code{opas_refresh()} is called automatically.
#'
#' Called internally by data-fetching functions that rely on the package
#' internal authentication state. Users do not normally need to call this
#' directly.
#'
#' @return Invisibly returns \code{NULL}.
#'
#' @noRd
opas_ensure_token <- function() {
  
  if (is.null(.opas_env$token)) {
    rlang::abort(
      "Not logged in. Please call opas_login() first.",
      class = "opas_auth_error"
    )
  }
  
  needs_refresh <- !is.null(.opas_env$expires_at) &&
    Sys.time() > .opas_env$expires_at - 60
  
  if (needs_refresh) {
    tryCatch(
      opas_refresh(),
      error = function(e) {
        rlang::abort(
          paste0(
            "Automatic token refresh failed. ",
            "Please call opas_login() again.\n",
            "Caused by: ", conditionMessage(e)
          ),
          class = "opas_auth_error"
        )
      }
    )
  }
  
  invisible(NULL)
}


#' Logout from OPAS API
#'
#' Invalidates the current session on the server and clears all
#' authentication state from the internal environment.
#'
#' Server-side logout is attempted on a best-effort basis. Local
#' authentication state is cleared regardless of whether the server-side
#' logout request succeeds.
#'
#' After calling this function, \code{\link{opas_login}} must be called again
#' before making API requests through the default interactive authentication
#' workflow.
#'
#' @return Invisibly returns \code{TRUE}.
#' @export
#'
#' @examples
#' \dontrun{
#' opas_logout()
#' }
opas_logout <- function() {
  
  # Best-effort server-side invalidation.
  # Do not use opas_request() here: logout should not trigger automatic
  # token refresh through opas_ensure_token().
  if (!is.null(.opas_env$token)) {
    req <- httr2::request(.opas_env$base_url) |>
      httr2::req_url_path_append("logout") |>
      httr2::req_headers(
        Authorization = paste("Bearer", .opas_env$token),
        Accept = "application/json"
      )
    
    tryCatch(
      httr2::req_perform(req),
      error = function(e) NULL
    )
  }
  
  .opas_env$token         <- NULL
  .opas_env$refresh_token <- NULL
  .opas_env$expires_at    <- NULL
  
  invisible(TRUE)
}