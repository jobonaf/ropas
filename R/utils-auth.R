#' Internal OPAS environment
#'
#' Stores API configuration and authentication state.
#' Initialized at package load; never access directly from user code.
#'
#' @keywords internal
.opas_env <- new.env(parent = emptyenv())
.opas_env$base_url    <- "https://opas.isprambiente.it/api/v1"
.opas_env$token        <- NULL
.opas_env$refresh_token <- NULL
.opas_env$expires_at   <- NULL


# Null-coalescing operator
#
# Returns \code{x} if it is not \code{NULL}, otherwise \code{y}.
# Equivalent to the native \code{\%||\%} introduced in R 4.4; defined here
# for compatibility with R >= 4.1.
`%||%` <- function(x, y) if (!is.null(x)) x else y


#' Parse expiry time from a JWT token
#'
#' Decodes the payload of a JWT (base64url) and extracts the `exp` claim
#' as a POSIXct timestamp in UTC.  No signature verification is performed;
#' this is used only for local expiry checks.
#'
#' @param token A JWT string (three base64url segments separated by dots).
#' @return A \code{POSIXct} value in UTC, or \code{NULL} if parsing fails.
#'
#' @keywords internal
.opas_jwt_exp <- function(token) {
  tryCatch({
    # JWT structure: header.payload.signature
    payload_b64 <- strsplit(token, "\\.", fixed = FALSE)[[1L]][2L]
    
    # base64url -> base64 standard: replace URL-safe chars, add padding
    payload_b64 <- gsub("-", "+", payload_b64, fixed = TRUE)
    payload_b64 <- gsub("_", "/", payload_b64, fixed = TRUE)
    padding     <- (4L - nchar(payload_b64) %% 4L) %% 4L
    payload_b64 <- paste0(payload_b64, strrep("=", padding))
    
    raw_bytes <- base64enc::base64decode(payload_b64)
    payload   <- jsonlite::fromJSON(rawToChar(raw_bytes))
    
    if (!is.null(payload$exp)) {
      as.POSIXct(payload$exp, origin = "1970-01-01", tz = "UTC")
    } else {
      NULL
    }
  }, error = function(e) NULL)
}