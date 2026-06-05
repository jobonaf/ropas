#' Perform an authenticated OPAS API request
#'
#' Internal helper used by all public API functions.  Handles token
#' validation, request construction, retry logic, and error reporting.
#'
#' All OPAS parameters are part of the URL path, not query strings, so
#' \code{query} will rarely be needed; it is retained for forward
#' compatibility only.
#'
#' JSON arrays of objects are returned as-is (i.e. as R lists), leaving
#' any coercion to data frames to the calling function.  This avoids
#' surprising behaviour with nested fields such as
#' \code{conversion_history} inside \code{/parameters}.
#'
#' @param path  Character scalar. API endpoint path, e.g. \code{"series/06"}
#'   or \code{"series-data/1234/2026-01-01T00:00:00/2026-02-01T00:00:00"}.
#'   Do not include a leading slash.
#' @param query Optional named list of URL query parameters.
#'
#' @return Parsed JSON response as an R list.
#'
#' @keywords internal
opas_request <- function(path, query = NULL) {
  
  opas_ensure_token()
  
  # --- Build request --------------------------------------------------------
  
  req <- httr2::request(.opas_env$base_url) |>
    httr2::req_url_path_append(path) |>
    httr2::req_headers(
      Authorization   = paste("Bearer", .opas_env$token),
      Accept          = "application/json",
      # Explicit Accept-Encoding ensures gzip decompression even when the
      # server (nginx + MojoJS) omits Content-Encoding in the response.
      `Accept-Encoding` = "gzip, deflate"
    )
  
  # Query parameters: do.call is required because req_url_query() uses ...
  # and does not accept a pre-built list directly.
  if (!is.null(query)) {
    req <- do.call(httr2::req_url_query, c(list(req), query))
  }
  
  # --- Retry logic ----------------------------------------------------------
  # Only retry on transient server-side and rate-limit errors (5xx, 429).
  # 4xx errors are definitive (bad path, bad credentials) and must not be
  # retried: a 401 in particular should surface immediately so the caller
  # can re-authenticate rather than burning three attempts.
  req <- req |>
    httr2::req_retry(
      max_tries    = 3L,
      is_transient = \(resp) httr2::resp_status(resp) %in%
        c(429L, 500L, 502L, 503L, 504L),
      backoff      = \(x) 2^x   # 2 s, 4 s, 8 s
    )
  
  # --- Perform --------------------------------------------------------------
  
  resp <- httr2::req_perform(req)
  status <- httr2::resp_status(resp)
  
  # --- Error handling -------------------------------------------------------
  
  if (status >= 400L) {
    # Try to extract a human-readable message from the JSON body (OPAS
    # returns { "message": "...", "error": "..." } on failures).
    body <- tryCatch(
      httr2::resp_body_json(resp, simplifyVector = FALSE),
      error = function(e) NULL
    )
    
    detail <- if (is.list(body)) {
      body$message %||% body$error %||% "(no detail)"
    } else {
      tryCatch(httr2::resp_body_string(resp), error = function(e) "(unreadable body)")
    }
    
    rlang::abort(
      message = paste0(
        "OPAS API error [HTTP ", status, "] at path '", path, "': ", detail
      ),
      class = "opas_api_error",
      body  = body,
      path  = path,
      status = status
    )
  }
  
  # --- Parse response -------------------------------------------------------
  # simplifyVector = FALSE keeps all arrays as R lists, avoiding unexpected
  # coercion of nested structures (e.g. conversion_history, series_data).
  # Callers are responsible for converting to data frames as appropriate.
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}