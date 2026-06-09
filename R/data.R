#' Retrieve OPAS time series measurements
#'
#' Downloads measurement data for a single data series from the OPAS API.
#' Three retrieval modes are supported:
#'
#' \itemize{
#'   \item \strong{Recent hours}: supply \code{last_hours}.
#'   \item \strong{Recent days} (daily-aggregated endpoint): supply
#'     \code{last_days}.
#'   \item \strong{Custom range}: supply both \code{start} and \code{end}.
#'     Use \code{daily = TRUE} to hit the daily-aggregated endpoint instead
#'     of the raw hourly one.
#' }
#'
#' \strong{Note on \code{measure_value}}: the API returns raw instrument
#' values.  This function exposes them as \code{value_raw}.  Conversion
#' metadata is available from catalogue endpoints such as
#' \code{\link{opas_series}} and \code{\link{opas_parameters}}.  Automatic
#' conversion is intentionally left to higher-level helper functions.
#'
#' \strong{Note on validity}: filter on \code{post_validity_code} to keep
#' only the records you trust:
#' \code{0} = valid, \code{1} = reconstructed, negative = invalid.
#'
#' \strong{Note on timestamps}: \code{measure_date_time} strings returned by
#' the OPAS API carry no explicit timezone offset and always represent
#' Italian standard time (UTC+1 fixed, no daylight saving), as confirmed
#' by ISPRA developers.  This is consistent with the legal reference time
#' required by D.Lgs. 155/2010 and EU Directive 2024/2881.  The
#' \code{datetime} column is parsed with \code{tz = "Etc/GMT-1"}.
#' For daily aggregates (\code{last_days} or \code{daily = TRUE}), each
#' record is timestamped at midnight (\code{00:00:00}) of the reference day.
#'
#' @param series_id Integer. Series identifier as returned by
#'   \code{\link{opas_series}} (\code{series_id} column).
#' @param start,end Start and end of the requested period.  Accepted inputs:
#'   \itemize{
#'     \item A \code{POSIXct} object.
#'     \item A character string in ISO 8601 format
#'       \code{"YYYY-MM-DDTHH:MM:SS"}, interpreted as UTC+1 fixed
#'       (\code{"Etc/GMT-1"}).
#'   }
#'   Both must be supplied together.
#' @param last_hours Integer. Return data for the last \emph{N} hours.
#'   Mutually exclusive with \code{last_days} and \code{start}/\code{end}.
#' @param last_days Integer. Return daily-aggregated data for the last
#'   \emph{N} days.  Mutually exclusive with \code{last_hours} and
#'   \code{start}/\code{end}.
#' @param daily Logical. When using a custom \code{start}/\code{end} range,
#'   set \code{TRUE} to use the daily-aggregated endpoint
#'   (\code{/series-data-dd/}) instead of the raw hourly one
#'   (\code{/series-data/}).  Ignored when \code{last_hours} or
#'   \code{last_days} is supplied.
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. This is useful for process-based parallel workflows.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per measurement,
#'   including:
#'   \describe{
#'     \item{datetime}{\code{POSIXct} in UTC+1 fixed (\code{"Etc/GMT-1"}),
#'       derived from \code{measure_date_time}.  See the note on timestamps
#'       in the Details section.}
#'     \item{value_raw}{\code{measure_value} as returned by the API; the
#'       source column \code{measure_value} is dropped.}
#'     \item{post_validity_code}{Primary validity flag when provided by the
#'       API (0 = valid, 1 = reconstructed, negative = invalid).}
#'     \item{series_id, station_id, station_name, parameter_name,
#'       parameter_unit}{Series context columns, prepended for convenience.
#'       \code{parameter_unit} is the raw measurement unit returned by the
#'       data endpoint.}
#'     \item{...}{All remaining API fields except \code{measure_value} and
#'       \code{measure_date_time}, which are replaced by \code{value_raw}
#'       and \code{datetime} respectively.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Last 24 hours
#' opas_get_data(12900, last_hours = 24)
#'
#' # Last 7 daily aggregates
#' opas_get_data(12900, last_days = 7)
#'
#' # Custom range (raw hourly)
#' opas_get_data(12900,
#'               start = "2026-01-01T00:00:00",
#'               end   = "2026-02-01T00:00:00")
#'
#' # Custom range (daily aggregates)
#' opas_get_data(12900,
#'               start = "2026-01-01T00:00:00",
#'               end   = "2026-02-01T00:00:00",
#'               daily = TRUE)
#'
#' # Stateless authentication object, useful in parallel workflows
#' auth <- opas_auth("user@arpa.fvg.it", "my_password")
#' opas_get_data(12900, last_hours = 24, auth = auth)
#' }
opas_get_data <- function(series_id,
                          start      = NULL,
                          end        = NULL,
                          last_hours = NULL,
                          last_days  = NULL,
                          daily      = FALSE,
                          auth       = NULL) {
  
  # --- Input validation -----------------------------------------------------
  
  series_id <- suppressWarnings(as.integer(series_id))
  if (is.na(series_id)) {
    rlang::abort("`series_id` must be numeric.")
  }
  
  n_mode <- (!is.null(last_hours)) + (!is.null(last_days)) +
    (!is.null(start) || !is.null(end))
  
  if (n_mode > 1L) {
    rlang::abort(paste0(
      "Supply exactly one retrieval mode: ",
      "`last_hours`, `last_days`, or `start`/`end`."
    ))
  }
  
  if (n_mode == 0L) {
    rlang::abort(paste0(
      "Provide one of: `last_hours`, `last_days`, or both `start` and `end`."
    ))
  }
  
  if ((!is.null(start) && is.null(end)) || (is.null(start) && !is.null(end))) {
    rlang::abort("`start` and `end` must be supplied together.")
  }
  
  if (!is.null(last_hours)) {
    last_hours <- suppressWarnings(as.integer(last_hours))
    
    if (is.na(last_hours) || last_hours <= 0L) {
      rlang::abort("`last_hours` must be a positive integer.")
    }
  }
  
  if (!is.null(last_days)) {
    last_days <- suppressWarnings(as.integer(last_days))
    
    if (is.na(last_days) || last_days <= 0L) {
      rlang::abort("`last_days` must be a positive integer.")
    }
  }
  
  # --- Build path -----------------------------------------------------------
  
  if (!is.null(last_hours)) {
    
    path <- sprintf("series-data/%d/%d", series_id, last_hours)
    
  } else if (!is.null(last_days)) {
    
    path <- sprintf("series-data-dd/%d/%d", series_id, last_days)
    
  } else {
    
    # Convert start/end to Unix epoch for unambiguous URL construction.
    # Character strings are interpreted as UTC+1 fixed ("Etc/GMT-1").
    start_ep <- .opas_to_epoch(start)
    end_ep   <- .opas_to_epoch(end)
    
    if (is.na(start_ep) || is.na(end_ep)) {
      rlang::abort(paste0(
        "`start` and `end` must be POSIXct or ISO 8601 strings ",
        "(\"YYYY-MM-DDTHH:MM:SS\")."
      ))
    }
    
    if (start_ep >= end_ep) {
      rlang::abort("`start` must be earlier than `end`.")
    }
    
    endpoint <- if (daily) "series-data-dd" else "series-data"
    path <- sprintf("%s/%d/%d/%d", endpoint, series_id, start_ep, end_ep)
  }
  
  # --- Request --------------------------------------------------------------
  
  res <- opas_request(path, auth = auth)
  
  # Response structure (from YAML DataSeries schema):
  # res$data$series_data  -> list of Data objects (measurements)
  # res$data$station_id, $station_name, $parameter_name, etc. -> context
  data_obj <- res$data
  
  if (is.null(data_obj)) {
    rlang::abort(
      "Unexpected API response: missing `data` field.",
      class = "opas_api_error"
    )
  }
  
  series_data <- data_obj$series_data
  
  if (is.null(series_data) || length(series_data) == 0L) {
    rlang::warn(paste0(
      "API returned no measurements for this query. ",
      "Try increasing the time window or using a different series."
    ))
    return(tibble::tibble())
  }
  
  # --- Parse ----------------------------------------------------------------
  # series_data is a list of lists (simplifyVector = FALSE); bind_rows()
  # flattens it. Context fields from the parent object are prepended as
  # columns so the tibble is self-contained.
  
  df <- dplyr::bind_rows(series_data)
  
  # Parse datetime as UTC+1 fixed (Italian standard time, no DST).
  df$datetime <- as.POSIXct(
    df$measure_date_time,
    format = "%Y-%m-%dT%H:%M:%S",
    tz     = "Etc/GMT-1"
  )
  
  if (any(is.na(df$datetime))) {
    rlang::warn("Some measurement timestamps could not be parsed.")
  }
  
  # value_raw is an alias for measure_value, kept for a cleaner interface.
  # The source column measure_value and the parsed measure_date_time are
  # dropped to avoid redundancy; all other API fields are preserved as-is.
  df$value_raw <- df$measure_value
  
  drop_cols <- c("measure_value", "measure_date_time")
  df <- df[, setdiff(names(df), drop_cols), drop = FALSE]
  
  # Prepend series context columns.
  context <- tibble::tibble(
    series_id      = data_obj$series_id      %||% series_id,
    station_id     = data_obj$station_id     %||% NA_integer_,
    station_name   = data_obj$station_name   %||% NA_character_,
    parameter_name = data_obj$parameter_name %||% NA_character_,
    parameter_unit = data_obj$parameter_unit %||% NA_character_
  )
  
  # Reorder robustly: context + datetime + value_raw + post_validity_code
  # if present, then all remaining columns.  dplyr::any_of() avoids
  # failures if OPAS changes the response schema and omits one of the
  # priority fields.
  priority <- c("datetime", "value_raw", "post_validity_code")
  
  df_ordered <- df |>
    dplyr::select(dplyr::any_of(priority), dplyr::everything())
  
  dplyr::bind_cols(
    context[rep(1L, nrow(df_ordered)), ],
    df_ordered
  )
}