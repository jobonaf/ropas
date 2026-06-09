#' Internal OPAS environment
#'
#' Stores API configuration and authentication state.
#' Initialized at package load; never access directly from user code.
#'
#' @noRd
.opas_env <- new.env(parent = emptyenv())

.opas_env$base_url      <- "https://opas.isprambiente.it/api/v1"
.opas_env$token         <- NULL
.opas_env$refresh_token <- NULL
.opas_env$expires_at    <- NULL


# Null-coalescing operator
#
# Returns x if it is not NULL, otherwise y.
# Equivalent to the native %||% introduced in R 4.4; defined here
# for compatibility with R >= 4.1.
`%||%` <- function(x, y) if (!is.null(x)) x else y


#' Parse expiry time from a JWT token
#'
#' Decodes the payload of a JWT (base64url) and extracts the `exp` claim
#' as a POSIXct timestamp in UTC. No signature verification is performed;
#' this is used only for local expiry checks.
#'
#' @param token A JWT string with three base64url segments separated by dots.
#' @param warn Logical. If TRUE, emit a warning when parsing fails.
#'
#' @return A POSIXct value in UTC, or NULL if parsing fails or the token
#'   does not contain an `exp` claim.
#'
#' @noRd
.opas_jwt_exp <- function(token, warn = FALSE) {
  
  fail <- function(msg) {
    if (isTRUE(warn)) {
      rlang::warn(
        paste0("Could not parse JWT expiry: ", msg),
        class = "opas_auth_warning"
      )
    }
    NULL
  }
  
  if (is.null(token) || !is.character(token) || length(token) != 1L ||
      is.na(token) || !nzchar(token)) {
    return(fail("token is missing or not a non-empty character scalar."))
  }
  
  tryCatch({
    
    # JWT structure: header.payload.signature
    parts <- strsplit(token, ".", fixed = TRUE)[[1L]]
    
    if (length(parts) != 3L) {
      return(fail("token does not contain three JWT segments."))
    }
    
    payload_b64 <- parts[[2L]]
    
    if (!nzchar(payload_b64)) {
      return(fail("JWT payload segment is empty."))
    }
    
    # base64url -> base64 standard: replace URL-safe chars, add padding
    payload_b64 <- gsub("-", "+", payload_b64, fixed = TRUE)
    payload_b64 <- gsub("_", "/", payload_b64, fixed = TRUE)
    
    padding <- (4L - nchar(payload_b64) %% 4L) %% 4L
    payload_b64 <- paste0(payload_b64, strrep("=", padding))
    
    raw_bytes <- base64enc::base64decode(payload_b64)
    payload   <- jsonlite::fromJSON(rawToChar(raw_bytes))
    
    if (is.null(payload$exp)) {
      return(fail("JWT payload does not contain an `exp` claim."))
    }
    
    expires_at <- as.POSIXct(
      payload$exp,
      origin = "1970-01-01",
      tz = "UTC"
    )
    
    if (is.na(expires_at)) {
      return(fail("JWT `exp` claim could not be converted to POSIXct."))
    }
    
    expires_at
    
  }, error = function(e) {
    fail(conditionMessage(e))
  })
}


#' Resolve OPAS token expiry time
#'
#' Determines the token expiry time using, in order:
#' \enumerate{
#'   \item the JWT `exp` claim;
#'   \item the `exp` field returned by the OPAS API response;
#'   \item a conservative fallback based on the current time.
#' }
#'
#' A warning is emitted when the fallback is used, because this means the
#' actual server-side token lifetime could not be determined.
#'
#' @param token JWT access token.
#' @param exp Optional Unix timestamp returned in the OPAS response body.
#' @param fallback_seconds Number of seconds to assume if expiry cannot be
#'   determined from either the token or the response body.
#'
#' @return A POSIXct expiry time in UTC.
#'
#' @noRd
.opas_resolve_expires_at <- function(token,
                                     exp = NULL,
                                     fallback_seconds = 3600) {
  
  jwt_exp <- .opas_jwt_exp(token, warn = TRUE)
  
  if (!is.null(jwt_exp)) {
    return(jwt_exp)
  }
  
  if (!is.null(exp)) {
    body_exp <- as.POSIXct(
      exp,
      origin = "1970-01-01",
      tz = "UTC"
    )
    
    if (!is.na(body_exp)) {
      return(body_exp)
    }
    
    rlang::warn(
      "OPAS response contained an `exp` field, but it could not be parsed.",
      class = "opas_auth_warning"
    )
  }
  
  rlang::warn(
    paste0(
      "Could not determine token expiry from JWT or response body. ",
      "Assuming a fallback lifetime of ", fallback_seconds, " seconds. ",
      "If the server uses a shorter lifetime, the token may expire earlier ",
      "than expected."
    ),
    class = "opas_auth_warning"
  )
  
  Sys.time() + fallback_seconds
}