#' Retrieve OPAS station log events
#'
#' Retrieves log events for a station over a date-time range.
#'
#' @param station_id Integer. Station identifier as returned by
#'   \code{\link{opas_stations}}.
#' @param start,end Start and end of the requested period. Accepted inputs:
#'   \itemize{
#'     \item A \code{POSIXct} object.
#'     \item A character string in ISO 8601 format
#'       \code{"YYYY-MM-DDTHH:MM:SS"}, interpreted as UTC+1 fixed
#'       (\code{"Etc/GMT-1"}).
#'   }
#'   Both must be supplied.
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. Useful for process-based parallel workflows.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per station log
#'   event. Key columns:
#'   \describe{
#'     \item{log_id}{Unique log identifier.}
#'     \item{log_date}{Event date-time as \code{POSIXct} in UTC+1 fixed
#'       (\code{"Etc/GMT-1"}), when returned by the API.}
#'     \item{log_daily}{Logical flag indicating daily log events.}
#'     \item{station_id, station_name}{Station identifiers.}
#'     \item{lt_name}{Log type name.}
#'     \item{log_title}{Log title.}
#'     \item{log_link}{URL to the OPAS portal, when available.}
#'     \item{log_obj}{List-column containing structured log details such
#'       as \code{desc} and \code{title}.}
#'     \item{log_insert_ts, log_update_ts}{Database timestamps parsed as
#'       \code{POSIXct} in UTC, when returned by the API.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' opas_station_log(
#'   station_id = 1167,
#'   start = "2026-01-01T00:00:00",
#'   end   = "2026-02-01T00:00:00"
#' )
#'
#' auth <- opas_auth("user@arpa.fvg.it", "my_password")
#' opas_station_log(
#'   station_id = 1167,
#'   start = "2026-01-01T00:00:00",
#'   end   = "2026-02-01T00:00:00",
#'   auth = auth
#' )
#' }
opas_station_log <- function(station_id, start, end, auth = NULL) {
  
  station_id <- suppressWarnings(as.integer(station_id))
  
  if (is.na(station_id)) {
    rlang::abort("`station_id` must be numeric.")
  }
  
  if (missing(start) || missing(end) || is.null(start) || is.null(end)) {
    rlang::abort("`start` and `end` must be supplied together.")
  }
  
  start_iso <- .opas_datetime_to_iso(start, arg = "start")
  end_iso   <- .opas_datetime_to_iso(end, arg = "end")
  
  # Validate temporal ordering using the same timezone convention used
  # elsewhere in the package.  The API expects ISO 8601 strings for this
  # endpoint, but epoch conversion is convenient and unambiguous for the
  # comparison.
  start_ep <- .opas_to_epoch(start_iso)
  end_ep   <- .opas_to_epoch(end_iso)
  
  if (is.na(start_ep) || is.na(end_ep)) {
    rlang::abort(paste0(
      "`start` and `end` must be POSIXct or ISO 8601 strings ",
      "(\"YYYY-MM-DDTHH:MM:SS\")."
    ))
  }
  
  if (start_ep >= end_ep) {
    rlang::abort("`start` must be earlier than `end`.")
  }
  
  path <- sprintf(
    "stations-log/%d/%s/%s",
    station_id,
    start_iso,
    end_iso
  )
  
  res <- opas_request(path, auth = auth)
  
  if (is.null(res$stations)) {
    rlang::abort(
      "Unexpected API response: missing `stations` field.",
      class = "opas_api_error"
    )
  }
  
  out <- .opas_parse_lookup_table(
    x = res$stations,
    field = "stations"
  )
  
  out <- .opas_parse_datetime_column(
    out,
    col = "log_date",
    tz = "Etc/GMT-1",
    truncate = FALSE
  )
  
  out <- .opas_parse_datetime_column(
    out,
    col = "log_insert_ts",
    tz = "UTC",
    truncate = TRUE
  )
  
  out <- .opas_parse_datetime_column(
    out,
    col = "log_update_ts",
    tz = "UTC",
    truncate = TRUE
  )
  
  out <- .opas_parse_datetime_column(
    out,
    col = "log_note_insert_ts",
    tz = "UTC",
    truncate = TRUE
  )
  
  out <- .opas_parse_datetime_column(
    out,
    col = "log_note_update_ts",
    tz = "UTC",
    truncate = TRUE
  )
  
  out
}