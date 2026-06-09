#' Convert a datetime value to Unix epoch
#'
#' Accepts POSIXct or an ISO 8601 character string; interprets character
#' input as Italian standard time (UTC+1 fixed).
#'
#' @param x POSIXct or character.
#' @return Integer Unix timestamp, or \code{NA_integer_} on failure.
#'
#' @noRd
.opas_to_epoch <- function(x) {
  if (inherits(x, "POSIXct")) {
    as.integer(x)
  } else {
    as.integer(as.POSIXct(
      as.character(x),
      format = "%Y-%m-%dT%H:%M:%S",
      tz     = "Etc/GMT-1"
    ))
  }
}


#' Parse a datetime column if present
#'
#' Internal helper used by synchro parsers.  If the column is missing,
#' the input data frame is returned unchanged.
#'
#' @param df Data frame or tibble.
#' @param col Character scalar. Column name.
#' @param tz Time zone used for parsing.
#' @param truncate Logical. If TRUE, only the first 19 characters are used.
#'
#' @return Modified data frame or tibble.
#'
#' @noRd
.opas_parse_datetime_column <- function(df,
                                        col,
                                        tz,
                                        truncate = FALSE) {
  if (!col %in% names(df)) {
    return(df)
  }
  
  x <- df[[col]]
  
  if (truncate) {
    x <- substr(x, 1L, 19L)
  }
  
  parsed <- as.POSIXct(
    x,
    format = "%Y-%m-%dT%H:%M:%S",
    tz = tz
  )
  
  if (any(is.na(parsed) & !is.na(x))) {
    rlang::warn(paste0(
      "Some values in `", col, "` could not be parsed as datetimes."
    ))
  }
  
  df[[col]] <- parsed
  df
}


#' Build a safe list key for synchro results
#'
#' @param series_id Series identifier, possibly missing.
#' @param station_id Station identifier, possibly missing.
#' @param index Integer fallback index.
#' @param regional Logical. If TRUE, include station ID in the key.
#'
#' @return Character scalar.
#'
#' @noRd
.opas_sync_key <- function(series_id,
                           station_id = NULL,
                           index = NULL,
                           regional = FALSE) {
  has_series <- !is.null(series_id) &&
    length(series_id) == 1L &&
    !is.na(series_id)
  
  has_station <- !is.null(station_id) &&
    length(station_id) == 1L &&
    !is.na(station_id)
  
  if (regional) {
    station_part <- if (has_station) {
      paste0("station_", station_id)
    } else {
      paste0("station_missing_", index %||% "unknown")
    }
    
    series_part <- if (has_series) {
      paste0("series_", series_id)
    } else {
      paste0("series_missing_", index %||% "unknown")
    }
    
    return(paste(station_part, series_part, sep = "_"))
  }
  
  if (has_series) {
    paste0("series_", series_id)
  } else {
    paste0("series_missing_", index %||% "unknown")
  }
}


#' Append a synchro result safely
#'
#' If a key already exists, rows are appended instead of silently
#' overwriting previous data.
#'
#' @param result Existing named list.
#' @param key Character scalar.
#' @param value Tibble to insert or append.
#'
#' @return Updated named list.
#'
#' @noRd
.opas_add_sync_result <- function(result, key, value) {
  if (!key %in% names(result)) {
    result[[key]] <- value
    return(result)
  }
  
  rlang::warn(paste0(
    "Duplicate synchro key `", key, "` encountered. ",
    "Rows were appended instead of overwriting previous data."
  ))
  
  result[[key]] <- dplyr::bind_rows(result[[key]], value)
  result
}


#' Parse a synchro series_data list into a tibble
#'
#' Shared helper for all synchro functions.  Flattens a list of measurement
#' records from \code{series_data} into a tibble, prepending context columns
#' and parsing datetime fields when present.
#'
#' @param series_data List of measurement records.
#' @param context Named list of context scalars (station_id, etc.).
#'
#' @return A \code{\link[tibble]{tibble}}, or an empty tibble if
#'   \code{series_data} is \code{NULL} or empty.
#'
#' @noRd
.opas_parse_synchro <- function(series_data, context) {
  
  if (is.null(series_data) || length(series_data) == 0L) {
    return(tibble::tibble())
  }
  
  df <- dplyr::bind_rows(series_data)
  
  if (nrow(df) == 0L) {
    return(tibble::tibble())
  }
  
  # Primary measurement datetime: Italian standard time, UTC+1 fixed.
  df <- .opas_parse_datetime_column(
    df,
    col = "measure_date_time",
    tz = "Etc/GMT-1",
    truncate = FALSE
  )
  
  if ("measure_date_time" %in% names(df)) {
    names(df)[names(df) == "measure_date_time"] <- "datetime"
  }
  
  # Insert/update timestamps are UTC.  OPAS may include fractional seconds
  # or offsets; keep the first 19 characters for stable parsing.
  df <- .opas_parse_datetime_column(
    df,
    col = "measure_insert_ts",
    tz = "UTC",
    truncate = TRUE
  )
  
  df <- .opas_parse_datetime_column(
    df,
    col = "measure_update_ts",
    tz = "UTC",
    truncate = TRUE
  )
  
  # value_raw alias; only created if measure_value is present.
  if ("measure_value" %in% names(df)) {
    df$value_raw <- df$measure_value
  } else {
    rlang::warn(
      "Synchro response does not contain `measure_value`; `value_raw` was not created."
    )
  }
  
  drop_cols <- c("measure_value")
  df <- df[, setdiff(names(df), drop_cols), drop = FALSE]
  
  # measure_update_obj is a list-column audit log; kept as-is when present.
  
  # Prepend context columns.
  ctx_tbl <- tibble::as_tibble(context)
  ctx_tbl <- ctx_tbl[rep(1L, nrow(df)), , drop = FALSE]
  
  # Robust ordering: do not fail if one of the priority columns is missing.
  priority <- c("datetime", "value_raw", "post_validity_code")
  
  df_ordered <- df |>
    dplyr::select(dplyr::any_of(priority), dplyr::everything())
  
  dplyr::bind_cols(ctx_tbl, df_ordered)
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
#' @param since POSIXct or ISO 8601 character string
#'   (\code{"YYYY-MM-DDTHH:MM:SS"}).  Only records inserted or updated after
#'   this timestamp are returned.  Character input is interpreted as Italian
#'   standard time (UTC+1 fixed).
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state.  Useful for process-based parallel workflows.
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
#' # Stateless authentication object
#' auth <- opas_auth("user@arpa.fvg.it", "my_password")
#' opas_sync_series(12900, since = "2026-06-01T00:00:00", auth = auth)
#' }
#'
#' @export
opas_sync_series <- function(series_id, since, auth = NULL) {
  
  series_id <- suppressWarnings(as.integer(series_id))
  if (is.na(series_id)) {
    rlang::abort("`series_id` must be numeric.")
  }
  
  since_ep <- .opas_to_epoch(since)
  if (is.na(since_ep)) {
    rlang::abort(paste0(
      "`since` must be a POSIXct or ISO 8601 string ",
      "(\"YYYY-MM-DDTHH:MM:SS\"). Got: ", since
    ))
  }
  
  path <- sprintf("series-data-synchro/%d/%d", series_id, since_ep)
  res  <- opas_request(path, auth = auth)
  
  if (is.null(res$data)) {
    rlang::abort(
      "Unexpected API response: missing `data` field.",
      class = "opas_api_error"
    )
  }
  
  d <- res$data
  
  context <- list(
    series_id           = d$series_id             %||% series_id,
    station_id          = d$station_id            %||% NA_integer_,
    station_name        = d$station_name          %||% NA_character_,
    parameter_name      = d$parameter_name        %||% NA_character_,
    parameter_unit      = d$parameter_unit        %||% NA_character_,
    parameter_conv_curr = d$parameter_conv_curr   %||%
      d$conversion_factor_curr %||% NA_real_,
    parameter_conv_unit = d$parameter_conv_unit   %||%
      d$conversion_unit %||% NA_character_
  )
  
  result <- .opas_parse_synchro(d$series_data, context)
  
  if (nrow(result) == 0L) {
    rlang::inform(paste0(
      "No updates for series ", series_id,
      " since ",
      format(as.POSIXct(since_ep, origin = "1970-01-01", tz = "Etc/GMT-1")),
      "."
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
#' \code{\link{opas_get_data}} with an explicit date range instead.
#'
#' @param station_id Integer. Station identifier from
#'   \code{\link{opas_stations}}.
#' @param since POSIXct or ISO 8601 character string.  See
#'   \code{\link{opas_sync_series}} for details.
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state.  Useful for process-based parallel workflows.
#'
#' @return A named list of \code{\link[tibble]{tibble}}s, one per series.
#'   Names are usually \code{"series_<series_id>"}.  If a series identifier
#'   is missing, a stable fallback name is generated.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' updates <- opas_sync_station(1167, since = "2026-06-01T00:00:00")
#' updates[sapply(updates, nrow) > 0]
#' }
opas_sync_station <- function(station_id, since, auth = NULL) {
  
  station_id <- suppressWarnings(as.integer(station_id))
  if (is.na(station_id)) {
    rlang::abort("`station_id` must be numeric.")
  }
  
  since_ep <- .opas_to_epoch(since)
  if (is.na(since_ep)) {
    rlang::abort(paste0(
      "`since` must be a POSIXct or ISO 8601 string ",
      "(\"YYYY-MM-DDTHH:MM:SS\"). Got: ", since
    ))
  }
  
  path <- sprintf("series-data-synchro-all/%d/%d", station_id, since_ep)
  res  <- opas_request(path, auth = auth)
  
  if (is.null(res$station)) {
    rlang::abort(
      "Unexpected API response: missing `station` field.",
      class = "opas_api_error"
    )
  }
  
  st <- res$station
  params <- st$parameters
  
  if (is.null(params) || length(params) == 0L) {
    rlang::warn("No series found for this station.")
    return(list())
  }
  
  result <- list()
  
  for (i in seq_along(params)) {
    p <- params[[i]]
    
    context <- list(
      series_id           = p$series_id             %||% NA_integer_,
      station_id          = st$station_id           %||% station_id,
      station_name        = st$station_name         %||% NA_character_,
      parameter_name      = p$parameter_name        %||% NA_character_,
      parameter_unit      = p$parameter_unit        %||% NA_character_,
      parameter_conv_curr = p$parameter_conv_curr   %||%
        p$conversion_factor_curr %||% NA_real_,
      parameter_conv_unit = p$parameter_conv_unit   %||%
        p$conversion_unit %||% NA_character_
    )
    
    key <- .opas_sync_key(
      series_id = context$series_id,
      station_id = context$station_id,
      index = i,
      regional = FALSE
    )
    
    result <- .opas_add_sync_result(
      result = result,
      key = key,
      value = .opas_parse_synchro(p$series_data, context)
    )
  }
  
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
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state.  Useful for process-based parallel workflows.
#'
#' @return A named list of \code{\link[tibble]{tibble}}s, one per
#'   station-series pair.  Names use the form
#'   \code{"station_<station_id>_series_<series_id>"} when identifiers are
#'   available.  Missing identifiers receive stable fallback names.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' since   <- as.POSIXct(Sys.time() - 86400, tz = "Etc/GMT-1")
#' updates <- opas_sync_region("06", since = since)
#' dplyr::bind_rows(updates[sapply(updates, nrow) > 0])
#' }
opas_sync_region <- function(region, since, auth = NULL) {
  
  region <- .opas_normalize_region(region)
  
  since_ep <- .opas_to_epoch(since)
  
  if (is.na(since_ep)) {
    rlang::abort(paste0(
      "`since` must be a POSIXct or ISO 8601 string ",
      "(\"YYYY-MM-DDTHH:MM:SS\"). Got: ", since
    ))
  }
  
  path <- sprintf("series-data-synchro-all/%s/%d", region, since_ep)
  res  <- opas_request(path, auth = auth)
  
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
  if (!is.null(stations$station_id)) {
    stations <- list(stations)
  }
  
  result <- list()
  idx <- 0L
  
  for (st in stations) {
    params <- st$parameters
    if (is.null(params) || length(params) == 0L) {
      next
    }
    
    for (p in params) {
      idx <- idx + 1L
      
      context <- list(
        series_id           = p$series_id             %||% NA_integer_,
        station_id          = st$station_id           %||% NA_integer_,
        station_name        = st$station_name         %||% NA_character_,
        parameter_name      = p$parameter_name        %||% NA_character_,
        parameter_unit      = p$parameter_unit        %||% NA_character_,
        parameter_conv_curr = p$parameter_conv_curr   %||%
          p$conversion_factor_curr %||% NA_real_,
        parameter_conv_unit = p$parameter_conv_unit   %||%
          p$conversion_unit %||% NA_character_
      )
      
      key <- .opas_sync_key(
        series_id = context$series_id,
        station_id = context$station_id,
        index = idx,
        regional = TRUE
      )
      
      result <- .opas_add_sync_result(
        result = result,
        key = key,
        value = .opas_parse_synchro(p$series_data, context)
      )
    }
  }
  
  result
}