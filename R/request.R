#' Resolve bearer token for an OPAS request
#'
#' Internal helper used by \code{opas_request()}. Authentication can come
#' from an explicit \code{ropas_auth} object, a raw bearer token, or the
#' package-global authentication state managed by \code{opas_login()}.
#'
#' @param auth Optional object of class \code{"ropas_auth"}.
#' @param token Optional raw bearer token.
#'
#' @return Character scalar: bearer token.
#'
#' @noRd
.opas_resolve_bearer_token <- function(auth = NULL, token = NULL) {
  
  if (!is.null(auth) && !is.null(token)) {
    rlang::abort(
      "Use only one of `auth` or `token`, not both.",
      class = "opas_auth_error"
    )
  }
  
  if (!is.null(auth)) {
    
    if (!inherits(auth, "ropas_auth")) {
      rlang::abort(
        "`auth` must be an object returned by opas_auth().",
        class = "opas_auth_error"
      )
    }
    
    if (is.null(auth$token) ||
        !is.character(auth$token) ||
        length(auth$token) != 1L ||
        is.na(auth$token) ||
        !nzchar(auth$token)) {
      rlang::abort(
        "`auth` does not contain a valid access token.",
        class = "opas_auth_error"
      )
    }
    
    if (!is.null(auth$expires_at)) {
      
      if (!inherits(auth$expires_at, "POSIXct") ||
          length(auth$expires_at) != 1L ||
          is.na(auth$expires_at)) {
        rlang::abort(
          "`auth$expires_at` must be a valid POSIXct scalar.",
          class = "opas_auth_error"
        )
      }
      
      if (Sys.time() > auth$expires_at - 60) {
        rlang::abort(
          paste0(
            "`auth` appears to be expired or close to expiry. ",
            "Create a fresh authentication object with opas_auth(), ",
            "or call opas_login() again."
          ),
          class = "opas_auth_error"
        )
      }
    }
    
    return(auth$token)
  }
  
  if (!is.null(token)) {
    
    if (!is.character(token) ||
        length(token) != 1L ||
        is.na(token) ||
        !nzchar(token)) {
      rlang::abort(
        "`token` must be a non-empty character scalar.",
        class = "opas_auth_error"
      )
    }
    
    return(token)
  }
  
  opas_ensure_token()
  .opas_env$token
}


#' Safely decode a response body as text
#'
#' Internal helper used for diagnostic messages. It first tries to read the
#' body as text. If that fails, it attempts raw-to-character conversion and
#' then manual gzip decompression.
#'
#' @param resp An \pkg{httr2} response object.
#' @param path API endpoint path, used only for diagnostics.
#'
#' @return Character scalar, or \code{"(unreadable body)"}.
#'
#' @noRd
.opas_resp_body_text <- function(resp, path) {
  
  txt <- tryCatch(
    httr2::resp_body_string(resp),
    error = function(e) NULL
  )
  
  if (!is.null(txt)) {
    return(txt)
  }
  
  raw_bytes <- tryCatch(
    httr2::resp_body_raw(resp),
    error = function(e) NULL
  )
  
  if (is.null(raw_bytes)) {
    return("(unreadable body)")
  }
  
  # Try plain raw-to-character first.
  txt_raw <- tryCatch(
    rawToChar(raw_bytes),
    error = function(e) NULL
  )
  
  if (!is.null(txt_raw)) {
    return(txt_raw)
  }
  
  # Then try manual gzip decompression.
  txt_gzip <- tryCatch({
    decompressed <- memDecompress(raw_bytes, type = "gzip")
    rawToChar(decompressed)
  }, error = function(e) NULL)
  
  txt_gzip %||% "(unreadable body)"
}


#' Parse an OPAS response body as JSON
#'
#' Internal helper used by \code{opas_request()}.
#'
#' The OPAS server may return gzip-compressed bodies without a
#' \code{Content-Encoding} header on some endpoints. In that case
#' \pkg{httr2} cannot automatically decompress the response. This helper
#' first tries the normal \code{httr2::resp_body_json()} path and then falls
#' back to manual gzip decompression.
#'
#' @param resp An \pkg{httr2} response object.
#' @param path API endpoint path, used only for diagnostics.
#' @param warn_unexpected_gzip Logical. If \code{TRUE}, emit a warning when
#'   manual gzip decompression is used.
#' @param error_on_parse Logical. If \code{TRUE}, abort when parsing fails.
#'   If \code{FALSE}, return \code{NULL} on parsing failure.
#'
#' @return Parsed JSON as an R list, or \code{NULL} if
#'   \code{error_on_parse = FALSE} and parsing fails.
#'
#' @noRd
.opas_resp_body_json <- function(resp,
                                 path,
                                 warn_unexpected_gzip = TRUE,
                                 error_on_parse = TRUE) {
  
  parsed <- tryCatch(
    httr2::resp_body_json(resp, simplifyVector = FALSE),
    error = function(e) e
  )
  
  if (!inherits(parsed, "error")) {
    return(parsed)
  }
  
  json_error <- parsed
  
  raw_bytes <- tryCatch(
    httr2::resp_body_raw(resp),
    error = function(e) e
  )
  
  if (inherits(raw_bytes, "error")) {
    if (isTRUE(error_on_parse)) {
      rlang::abort(
        paste0(
          "Failed to parse API response at path '", path, "': ",
          "response body could not be read.\n",
          "Original JSON error: ", conditionMessage(json_error), "\n",
          "Raw body error: ", conditionMessage(raw_bytes)
        ),
        class = "opas_api_error"
      )
    }
    return(NULL)
  }
  
  decompressed <- tryCatch(
    memDecompress(raw_bytes, type = "gzip"),
    error = function(e) e
  )
  
  if (inherits(decompressed, "error")) {
    if (isTRUE(error_on_parse)) {
      rlang::abort(
        paste0(
          "Failed to parse API response at path '", path, "': ",
          "body is not valid JSON and manual gzip decompression failed.\n",
          "Original JSON error: ", conditionMessage(json_error), "\n",
          "Gzip error: ", conditionMessage(decompressed)
        ),
        class = "opas_api_error"
      )
    }
    return(NULL)
  }
  
  txt <- tryCatch(
    rawToChar(decompressed),
    error = function(e) e
  )
  
  if (inherits(txt, "error")) {
    if (isTRUE(error_on_parse)) {
      rlang::abort(
        paste0(
          "Failed to parse API response at path '", path, "': ",
          "gzip decompression succeeded, but decompressed bytes could not ",
          "be converted to character data.\n",
          "Original JSON error: ", conditionMessage(json_error), "\n",
          "Character conversion error: ", conditionMessage(txt)
        ),
        class = "opas_api_error"
      )
    }
    return(NULL)
  }
  
  if (isTRUE(warn_unexpected_gzip)) {
    rlang::warn(
      paste0(
        "OPAS response at path '", path, "' appeared to be gzip-compressed ",
        "without a usable Content-Encoding header. ",
        "The response was manually decompressed."
      ),
      class = "opas_api_warning"
    )
  }
  
  parsed_gzip <- tryCatch(
    jsonlite::fromJSON(txt, simplifyVector = FALSE),
    error = function(e) e
  )
  
  if (inherits(parsed_gzip, "error")) {
    if (isTRUE(error_on_parse)) {
      rlang::abort(
        paste0(
          "Failed to parse manually decompressed API response at path '",
          path, "' as JSON.\n",
          "Original JSON error: ", conditionMessage(json_error), "\n",
          "Decompressed JSON error: ", conditionMessage(parsed_gzip)
        ),
        class = "opas_api_error"
      )
    }
    return(NULL)
  }
  
  parsed_gzip
}


#' Perform an authenticated OPAS API request
#'
#' Internal helper used by all public API functions. Handles token
#' validation, request construction, retry logic, error reporting, and JSON
#' parsing.
#'
#' Authentication normally comes from the package-global state populated by
#' \code{\link{opas_login}}. For advanced workflows, especially
#' process-based parallel execution, callers may pass an explicit
#' \code{auth} object returned by \code{\link{opas_auth}}, or a raw bearer
#' \code{token}.
#'
#' All OPAS parameters are part of the URL path, not query strings, so
#' \code{query} will rarely be needed; it is retained for forward
#' compatibility only.
#'
#' JSON arrays of objects are returned as-is as R lists. Any coercion to
#' data frames is left to the calling function. This avoids surprising
#' behaviour with nested fields such as \code{conversion_history} inside
#' \code{/parameters}.
#'
#' Diagnostic logging can be enabled with
#' \code{options(ropas.verbose = TRUE)}.
#'
#' Warnings about unexpected gzip-compressed responses can be disabled with
#' \code{options(ropas.warn_unexpected_gzip = FALSE)}.
#'
#' @param path Character scalar. API endpoint path, e.g. \code{"series/06"}
#'   or \code{"series-data/1234/1704063600/1706742000"}.
#'   Do not include a leading slash.
#' @param query Optional named list of URL query parameters.
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#' @param token Optional raw bearer token. Mainly intended for internal or
#'   diagnostic use. Public endpoint functions should expose \code{auth},
#'   not \code{token}, because raw tokens do not carry expiry metadata.
#'
#' @return Parsed JSON response as an R list.
#'
#' @noRd
opas_request <- function(path,
                         query = NULL,
                         auth = NULL,
                         token = NULL) {
  
  # --- Input validation -----------------------------------------------------
  
  if (!is.character(path) ||
      length(path) != 1L ||
      is.na(path) ||
      !nzchar(path)) {
    rlang::abort(
      "`path` must be a non-empty character scalar.",
      class = "opas_api_error"
    )
  }
  
  if (grepl("^/", path)) {
    rlang::abort(
      "`path` must not start with a leading slash.",
      class = "opas_api_error"
    )
  }
  
  if (!is.null(query)) {
    if (!is.list(query)) {
      rlang::abort(
        "`query` must be a named list.",
        class = "opas_api_error"
      )
    }
    
    if (is.null(names(query)) || any(!nzchar(names(query)))) {
      rlang::abort(
        "`query` must be a fully named list.",
        class = "opas_api_error"
      )
    }
  }
  
  bearer_token <- .opas_resolve_bearer_token(
    auth = auth,
    token = token
  )
  
  # --- Build request --------------------------------------------------------
  
  req <- httr2::request(.opas_env$base_url) |>
    httr2::req_url_path_append(path) |>
    httr2::req_headers(
      Authorization     = paste("Bearer", bearer_token),
      Accept            = "application/json",
      # Some OPAS endpoints may return gzip-compressed bodies
      # inconsistently. Explicitly advertising gzip support keeps the
      # normal path correct when the server also sends Content-Encoding.
      `Accept-Encoding` = "gzip, deflate"
    )
  
  # Query parameters: do.call is required because req_url_query() uses ...
  # and does not accept a pre-built list directly.
  if (!is.null(query)) {
    req <- do.call(httr2::req_url_query, c(list(req), query))
  }
  
  # --- Retry and error policy ----------------------------------------------
  # Only retry on transient server-side and rate-limit errors (5xx, 429).
  # 4xx errors are definitive (bad path, bad credentials) and must not be
  # retried. req_error(FALSE) is required so that HTTP >= 400 responses
  # reach the custom error handling block below instead of being converted
  # immediately into native httr2 errors.
  
  req <- req |>
    httr2::req_retry(
      max_tries    = 3L,
      is_transient = \(resp) httr2::resp_status(resp) %in%
        c(429L, 500L, 502L, 503L, 504L),
      backoff      = \(x) 2^x
    ) |>
    httr2::req_error(is_error = \(resp) FALSE)
  
  # --- Perform --------------------------------------------------------------
  
  if (isTRUE(getOption("ropas.verbose", FALSE))) {
    rlang::inform(paste0("OPAS request: GET /", path))
  }
  
  resp <- httr2::req_perform(req)
  status <- httr2::resp_status(resp)
  
  if (isTRUE(getOption("ropas.verbose", FALSE))) {
    rlang::inform(paste0(
      "OPAS response: HTTP ", status, " for /", path
    ))
  }
  
  # Whether to warn when the manual gzip fallback is used.
  warn_unexpected_gzip <- isTRUE(
    getOption("ropas.warn_unexpected_gzip", TRUE)
  )
  
  # --- Error handling -------------------------------------------------------
  
  if (status >= 400L) {
    
    body <- .opas_resp_body_json(
      resp,
      path = path,
      warn_unexpected_gzip = warn_unexpected_gzip,
      error_on_parse = FALSE
    )
    
    detail <- if (is.list(body)) {
      body$message %||% body$error %||% "(no detail)"
    } else {
      .opas_resp_body_text(resp, path = path)
    }
    
    rlang::abort(
      message = paste0(
        "OPAS API error [HTTP ", status, "] at path '", path, "': ", detail
      ),
      class = "opas_api_error",
      response_body = body,
      path = path,
      status = status
    )
  }
  
  # --- Parse successful response -------------------------------------------
  # simplifyVector = FALSE keeps all arrays as R lists, avoiding unexpected
  # coercion of nested structures (e.g. conversion_history, series_data).
  # Callers are responsible for converting to data frames as appropriate.
  
  parsed <- .opas_resp_body_json(
    resp,
    path = path,
    warn_unexpected_gzip = warn_unexpected_gzip,
    error_on_parse = TRUE
  )
  
  parsed
}