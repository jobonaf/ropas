#' Login to OPAS API
#'
#' Authenticates with the OPAS web service and stores the JWT access token
#' and refresh token internally.  Must be called before any other API
#' function.  The token is valid for approximately 1 hour; subsequent calls
#' are handled automatically by \code{opas_ensure_token()}.
#'
#' @param email    Email address registered on the OPAS portal.
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
  
  req <- httr2::request(.opas_env$base_url) |>
    httr2::req_url_path_append("login") |>
    httr2::req_method("POST") |>
    httr2::req_body_json(list(
      email    = email,
      password = password
    ))
  
  resp <- httr2::req_perform(req)
  
  # req_perform() already throws on network errors; check HTTP status
  # explicitly so we can give a clear message before touching the body.
  if (httr2::resp_status(resp) != 200L) {
    rlang::abort(paste0(
      "Login failed (HTTP ", httr2::resp_status(resp), "). ",
      "Check credentials."
    ))
  }
  
  data <- httr2::resp_body_json(resp)
  
  .opas_env$token         <- data$token
  .opas_env$refresh_token <- data$refreshToken
  
  # Prefer expiry from JWT payload; fall back to the `exp` field in the
  # response body (both contain the same Unix timestamp, but parsing the
  # token directly avoids relying on the response structure).
  .opas_env$expires_at <- .opas_jwt_exp(data$token) %||%
    if (!is.null(data$exp)) {
      as.POSIXct(data$exp, origin = "1970-01-01", tz = "UTC")
    } else {
      Sys.time() + 3600
    }
  
  invisible(TRUE)
}


#' Refresh the OPAS access token
#'
#' Uses the stored refresh token to obtain a new access token from
#' \code{POST /refresh-token}.  Called automatically by
#' \code{opas_ensure_token()}; users should not normally need to call this
#' directly.
#'
#' Note: the \code{/refresh-token} endpoint returns only a new \code{token};
#' the refresh token itself is not rotated, so \code{.opas_env$refresh_token}
#' is left unchanged.
#'
#' @return Invisibly returns \code{TRUE} on success.
#'
#' @keywords internal
opas_refresh <- function() {
  
  if (is.null(.opas_env$refresh_token)) {
    rlang::abort("No refresh token available. Please call opas_login() again.")
  }
  
  req <- httr2::request(.opas_env$base_url) |>
    httr2::req_url_path_append("refresh-token") |>
    httr2::req_method("POST") |>
    httr2::req_body_json(list(
      refreshToken = .opas_env$refresh_token
    ))
  
  resp <- httr2::req_perform(req)
  
  if (httr2::resp_status(resp) != 200L) {
    rlang::abort(paste0(
      "Token refresh failed (HTTP ", httr2::resp_status(resp), "). ",
      "Please call opas_login() again."
    ))
  }
  
  data <- httr2::resp_body_json(resp)
  
  # /refresh-token returns only { token } - no refreshToken, no exp field.
  # Extract expiry from the JWT payload itself.
  .opas_env$token      <- data$token
  .opas_env$expires_at <- .opas_jwt_exp(data$token) %||% (Sys.time() + 3600)
  # .opas_env$refresh_token is intentionally NOT updated (not returned by API)
  
  invisible(TRUE)
}


#' Ensure a valid OPAS token is available
#'
#' Checks that the user is logged in and that the current token has not
#' expired (with a 60-second safety margin).  If the token is close to
#' expiry, \code{opas_refresh()} is called automatically.
#'
#' Called internally by all data-fetching functions; users do not need to
#' call this directly.
#'
#' @return Invisibly returns \code{NULL}.
#'
#' @keywords internal
opas_ensure_token <- function() {
  
  if (is.null(.opas_env$token)) {
    rlang::abort("Not logged in. Please call opas_login() first.")
  }
  
  if (!is.null(.opas_env$expires_at) &&
      Sys.time() > .opas_env$expires_at - 60) {
    tryCatch(
      opas_refresh(),
      error = function(e) {
        rlang::abort(
          paste0(
            "Automatic token refresh failed. ",
            "Please call opas_login() again.\n",
            "Caused by: ", conditionMessage(e)
          )
        )
      }
    )
  }
  
  invisible(NULL)
}


#' Logout from OPAS API
#'
#' Invalidates the current session on the server and clears all
#' authentication state from the internal environment.  After calling this
#' function, \code{\link{opas_login}} must be called again before making
#' any further API requests.
#'
#' @return Invisibly returns \code{TRUE} on success.
#' @export
#'
#' @examples
#' \dontrun{
#' opas_logout()
#' }
opas_logout <- function() {
  
  # Best-effort server-side invalidation: if the token is already expired
  # or missing, we still clear the local state.
  if (!is.null(.opas_env$token)) {
    tryCatch(
      opas_request("logout"),
      error = function(e) NULL
    )
  }
  
  # Clear all authentication state regardless of server response.
  .opas_env$token         <- NULL
  .opas_env$refresh_token <- NULL
  .opas_env$expires_at    <- NULL
  
  invisible(TRUE)
}