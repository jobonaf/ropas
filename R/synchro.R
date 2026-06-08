#' Parse a synchro series_data list into a tibble
#'
#' Shared helper for all synchro functions.  Flattens a list of measurement
#' records (from \code{series_data}) into a tibble, prepending context
#' columns and parsing the datetime fields.
#'
#' @param series_data  List of measurement records.
#' @param context      Named list of context scalars (station_id, etc.).
#' @return A \code{\link[tibble]{tibble}}, or an empty tibble if
#'   \code{series_data} is \code{NULL} or empty.
#'
#' @keywords internal
.opas_parse_synchro <- function(series_data, context) {
  
  if (is.null(series_data) || length(series_data) == 0L) {
    return(tibble::tibble())
  }
  
  df <- dplyr::bind_rows(series_data)
  
  # Primary datetime: Italian standard time (UTC+1 fixed), confirmed by ISPRA.
  df$datetime <- as.POSIXct(df$measure_date_time,
                            format = "%Y-%m-%dT%H:%M:%S",
                            tz     = "Etc/GMT-1")
  
  # Update timestamps: stored in UTC (note "+00" suffix in measure_update_obj).
  # Parse without the fractional seconds and offset for simplicity.
  df$measure_insert_ts <- as.POSIXct(
    substr(df$measure_insert_ts, 1L, 19L),
    format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"
  )
  df$measure_update_ts <- as.POSIXct(
    substr(df$measure_update_ts, 1L, 19L),
    format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"
  )
  
  # value_raw alias; drop redundant source column.
  df$value_raw          <- df$measure_value
  drop_cols             <- c("measure_value", "measure_date_time")
  df                    <- df[, setdiff(names(df), drop_cols)]
  
  # measure_update_obj is a list-column (audit log); kept as-is.
  
  # Prepend context columns.
  ctx_tbl <- tibble::as_tibble(context)
  ctx_tbl <- ctx_tbl[rep(1L, nrow(df)), ]
  
  priority <- c("datetime", "value_raw", "post_validity_code")
  rest     <- setdiff(names(df), priority)
  
  dplyr::bind_cols(ctx_tbl, df[, c(priority, rest)])
}

#' Convert a datetime value to Unix epoch
#'
#' Accepts POSIXct or an ISO 8601 character string; interprets character
#' input as Italian standard time (UTC+1 fixed).
#'
#' @param x POSIXct or character.
#' @return Integer Unix timestamp, or \code{NA_integer_} on failure.
#'
#' @keywords internal
.opas_to_epoch <- function(x) {
  if (inherits(x, "POSIXct")) {
    as.integer(x)
  } else {
    as.integer(as.POSIXct(as.character(x),
                          format = "%Y-%m-%dT%H:%M:%S",
                          tz     = "Etc/GMT-1"))
  }
}


#' Retrieve updated measurements for a single series
#'
#' Downloads all measurements for one data series that have been inserted
#' or modified after \code{since}.  This endpoint is designed for
#' incremental synchronisation: store the timestamp of the last successful
#' sync and pass it as \code{since} on the next run.
#'
#' The response includes both newly inserted records and records whose
#' validity codes were updated after the initial insertion.
#' \code{measure_update_ts} indicates when each record was last modified;
#' \code{measure_update_obj} (list-column) contains the full audit log of
#' changes.
#'
#' @param series_id Integer. Series identifier from \code{\link{opas_series}}.
#' @param since POSIXct or ISO 8601 character string (\code{"YYYY-MM-DDTHH:MM:SS"}).
#'   Only records inserted or updated after this timestamp are returned.
#'   Interpreted as Italian standard time (UTC+1 fixed).
#'
#' @return A \code{\link[tibble]{tibble}} with one row per updated
#'   measurement, or an empty tibble if no updates are available.
#'   Includes all fields from \code{\link{opas_get_data}} plus:
#'   \describe{
#'     \item{measure_insert_ts}{\code{POSIXct} (UTC) of initial insertion.}
#'     \item{measure_update_ts}{\code{POSIXct} (UTC) of last modification.}
#'     \item{measure_update_obj}{List-column; audit log of changes with old
#'       and new validity codes and values.}
#'   }
#' 
#' @note The \code{series_id} column in the returned tibble reflects the
#'   internal OPAS series identifier as returned by the API, which may
#'   differ from the \code{series_id} used to query the endpoint.
#'   Use \code{\link{opas_series}} to reconcile the two identifiers.
#'
#' @examples
#' \dontrun{
#' # Records updated since 1 June 2026
#' opas_sync_series(12900, since = "2026-06-01T00:00:00")
#'
#' # Incremental sync pattern
#' last_sync <- as.POSIXct("2026-06-01T00:00:00", tz = "Etc/GMT-1")
#' new_data  <- opas_sync_series(12900, since = last_sync)
#' if (nrow(new_data) > 0) last_sync <- max(new_data$measure_update_ts)
#' }
#'
#' @export
opas_sync_series <- function(series_id, since) {
  
  since_ep <- .opas_to_epoch(since)
  if (is.na(since_ep)) {
    rlang::abort(paste0(
      "`since` must be a POSIXct or ISO 8601 string ",
      "(\"YYYY-MM-DDTHH:MM:SS\"). Got: ", since
    ))
  }
  
  path <- sprintf("series-data-synchro/%d/%d", as.integer(series_id), since_ep)
  res  <- opas_request(path)
  
  if (is.null(res$data)) {
    rlang::abort(
      "Unexpected API response: missing `data` field.",
      class = "opas_api_error"
    )
  }
  
  d <- res$data
  context <- list(
    series_id      = d$series_id      %||% as.integer(series_id),
    station_id     = d$station_id     %||% NA_integer_,
    station_name   = d$station_name   %||% NA_character_,
    parameter_name = d$parameter_name %||% NA_character_,
    parameter_unit = d$parameter_unit %||% NA_character_
  )
  
  result <- .opas_parse_synchro(d$series_data, context)
  
  if (nrow(result) == 0L) {
    rlang::inform(paste0(
      "No updates for series ", series_id,
      " since ", format(as.POSIXct(since_ep, origin = "1970-01-01", tz = "Etc/GMT-1")), "."
    ))
  }
  
  result
}


#' Retrieve updated measurements for all series at a station
#'
#' Downloads all measurements for every series at a given station that
#' have been inserted or modified after \code{since}.  The response covers
#' all parameters measured at the station; series with no updates since
#' \code{since} return an empty tibble.
#'
#' This endpoint can return very large datasets if \code{since} is far in
#' the past.  For the first full load of a station, consider using
#' \code{\link{opas_get_data}} with an explicit date range
#' instead.
#'
#' @param station_id Integer. Station identifier from
#'   \code{\link{opas_stations}}.
#' @param since POSIXct or ISO 8601 character string.  See
#'   \code{\link{opas_sync_series}} for details.
#'
#' @return A named list of \code{\link[tibble]{tibble}}s, one per series.
#'   Names are \code{"series_<series_id>"}.  Series with no updates are
#'   included as empty tibbles.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' updates <- opas_sync_station(1167, since = "2026-06-01T00:00:00")
#' # Series with actual data
#' updates[sapply(updates, nrow) > 0]
#' }
opas_sync_station <- function(station_id, since) {
  
  since_ep <- .opas_to_epoch(since)
  if (is.na(since_ep)) {
    rlang::abort(paste0(
      "`since` must be a POSIXct or ISO 8601 string ",
      "(\"YYYY-MM-DDTHH:MM:SS\"). Got: ", since
    ))
  }
  
  path <- sprintf("series-data-synchro-all/%d/%d",
                  as.integer(station_id), since_ep)
  res  <- opas_request(path)
  
  if (is.null(res$station)) {
    rlang::abort(
      "Unexpected API response: missing `station` field.",
      class = "opas_api_error"
    )
  }
  
  st     <- res$station
  params <- st$parameters
  
  if (is.null(params) || length(params) == 0L) {
    rlang::warn("No series found for this station.")
    return(list())
  }
  
  # Parse each series independently; series with NULL series_data -> empty tibble.
  result <- lapply(params, function(p) {
    context <- list(
      series_id      = p$series_id      %||% NA_integer_,
      station_id     = st$station_id    %||% as.integer(station_id),
      station_name   = st$station_name  %||% NA_character_,
      parameter_name = p$parameter_name %||% NA_character_,
      parameter_unit = p$parameter_unit %||% NA_character_
    )
    .opas_parse_synchro(p$series_data, context)
  })
  
  # Name the list by series_id for easy access.
  series_ids <- sapply(params, function(p) p$series_id %||% NA_integer_)
  names(result) <- paste0("series_", series_ids)
  
  result
}


#' Retrieve updated measurements for all series in a region
#'
#' Downloads all measurements for every series in a given region that
#' have been inserted or modified after \code{since}.
#'
#' \strong{Warning}: this endpoint can return extremely large datasets.
#' Use with a recent \code{since} value (e.g. last 24 hours) for routine
#' incremental synchronisation.  For historical backfills, prefer
#' \code{\link{opas_sync_station}} called iteratively per station.
#'
#' @param region Character. ISTAT region code (e.g. \code{"06"}).
#'   Zero-padded automatically if needed.
#' @param since POSIXct or ISO 8601 character string.  See
#'   \code{\link{opas_sync_series}} for details.
#'
#' @return A named list of \code{\link[tibble]{tibble}}s, one per series,
#'   named \code{"series_<series_id>"}. Series with no updates are included
#'   as empty tibbles.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Incremental sync for FVG - last 24 hours
#' since   <- as.POSIXct(Sys.time() - 86400, tz = "Etc/GMT-1")
#' updates <- opas_sync_region("06", since = since)
#' # Bind non-empty results into a single tibble
#' dplyr::bind_rows(updates[sapply(updates, nrow) > 0])
#' }
opas_sync_region <- function(region, since) {
  
  region   <- sprintf("%02d", as.integer(region))
  since_ep <- .opas_to_epoch(since)
  
  if (is.na(since_ep)) {
    rlang::abort(paste0(
      "`since` must be a POSIXct or ISO 8601 string ",
      "(\"YYYY-MM-DDTHH:MM:SS\"). Got: ", since
    ))
  }
  
  path <- sprintf("series-data-synchro-all/%s/%d", region, since_ep)
  res  <- opas_request(path)
  
  # Region synchro returns a list of station objects at the top level.
  # Each station has the same structure as station synchro.
  stations <- res$stations %||% res$station
  
  if (is.null(stations)) {
    rlang::abort(
      "Unexpected API response: missing `stations` field.",
      class = "opas_api_error"
    )
  }
  
  # Normalise: single station returned as list -> wrap in list.
  if (!is.null(stations$station_id)) stations <- list(stations)
  
  result <- list()
  
  for (st in stations) {
    params <- st$parameters
    if (is.null(params) || length(params) == 0L) next
    
    for (p in params) {
      context <- list(
        series_id      = p$series_id      %||% NA_integer_,
        station_id     = st$station_id    %||% NA_integer_,
        station_name   = st$station_name  %||% NA_character_,
        parameter_name = p$parameter_name %||% NA_character_,
        parameter_unit = p$parameter_unit %||% NA_character_
      )
      key          <- paste0("series_", context$series_id)
      result[[key]] <- .opas_parse_synchro(p$series_data, context)
    }
  }
  
  result
}