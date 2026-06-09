#' Validate an OPAS statistics year
#'
#' Internal helper used by statistics endpoints.
#'
#' @param year Integer or character. Four-digit year.
#'
#' @return Integer year.
#'
#' @noRd
.opas_validate_stats_year <- function(year) {
  
  year <- suppressWarnings(as.integer(year))
  
  if (is.na(year) || nchar(as.character(year)) != 4L) {
    rlang::abort("`year` must be a four-digit integer (e.g. 2025).")
  }
  
  if (year >= as.integer(format(Sys.Date(), "%Y"))) {
    rlang::abort(paste0(
      "Annual statistics are only available for completed years. ",
      "Got: ", year, "."
    ))
  }
  
  year
}


#' Parse a Date column if present
#'
#' Internal helper used by statistics endpoints. If the column is missing,
#' the input data frame is returned unchanged.
#'
#' @param df Data frame or tibble.
#' @param col Character scalar. Column name.
#'
#' @return Modified data frame or tibble.
#'
#' @noRd
.opas_parse_date_column <- function(df, col) {
  
  if (!col %in% names(df)) {
    return(df)
  }
  
  x <- df[[col]]
  parsed <- as.Date(x)
  
  if (any(is.na(parsed) & !is.na(x))) {
    rlang::warn(paste0(
      "Some values in `", col, "` could not be parsed as dates."
    ))
  }
  
  df[[col]] <- parsed
  df
}


#' Parse OPAS statistics results
#'
#' Internal helper used by statistics endpoints.
#'
#' @param statistics_results List returned by OPAS.
#'
#' @return A \code{\link[tibble]{tibble}}.
#'
#' @noRd
.opas_parse_statistics_results <- function(statistics_results) {
  
  if (is.null(statistics_results) || length(statistics_results) == 0L) {
    return(tibble::tibble())
  }
  
  df <- dplyr::bind_rows(statistics_results)
  
  if (nrow(df) == 0L) {
    return(tibble::tibble())
  }
  
  df <- .opas_parse_date_column(df, "result_from")
  df <- .opas_parse_date_column(df, "result_to")
  
  df
}


#' Retrieve OPAS annual statistics for a station
#'
#' Downloads pre-computed annual statistics for all parameters measured at
#' a given station. Statistics include regulatory limit comparisons
#' (threshold, exceedances, compliance) where applicable.
#'
#' Only complete years are available; the current year returns no results
#' as statistics are computed at year-end.
#'
#' Daily (\code{D}) and monthly (\code{M}) aggregation types exist in the
#' API schema but return no data in the current OPAS deployment. This
#' function therefore only supports annual (\code{Y}) statistics.
#'
#' @param station_id Integer. Station identifier as returned by
#'   \code{\link{opas_stations}} (\code{station_id} column).
#' @param year Integer or character. Four-digit year (e.g. \code{2025}).
#'   Must be a completed year.
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. Useful for process-based parallel workflows.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per
#'   statistic × limit combination, including:
#'   \describe{
#'     \item{series_id, station_id, parameter_id, pollutant_id}{
#'       Identifiers linking to other catalogue tables.}
#'     \item{stat_poll_id, stat_poll_type}{Statistic-pollutant combination
#'       identifier and aggregation type (\code{"Y"}).}
#'     \item{limit_id, limit_description, limit_threshold,
#'       limit_exceedances}{Regulatory limit details; \code{NA} when no
#'       limit is defined for the statistic.}
#'     \item{result_from, result_to}{Coverage period as \code{Date} objects,
#'       when returned by the API.}
#'     \item{result_value}{Computed statistic value.}
#'     \item{result_exceedance}{Logical; \code{TRUE} if the limit threshold
#'       was exceeded.}
#'     \item{result_valid}{Logical; \code{TRUE} if sufficient valid data
#'       were available to compute the statistic.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Annual statistics for station 1167, year 2025
#' opas_get_station_stats(station_id = 1167, year = 2025)
#'
#' # Keep only results with a defined regulatory limit
#' stats <- opas_get_station_stats(1167, 2025)
#' stats[!is.na(stats$limit_id), ]
#'
#' # Stateless authentication object
#' auth <- opas_auth("user@arpa.fvg.it", "my_password")
#' opas_get_station_stats(1167, 2025, auth = auth)
#' }
opas_get_station_stats <- function(station_id, year, auth = NULL) {
  
  # --- Input validation -----------------------------------------------------
  
  station_id <- suppressWarnings(as.integer(station_id))
  
  if (is.na(station_id)) {
    rlang::abort("`station_id` must be numeric.")
  }
  
  year <- .opas_validate_stats_year(year)
  
  path <- sprintf(
    "statistics-station-data/Y/%d/%d",
    station_id,
    year
  )
  
  # --- Request --------------------------------------------------------------
  
  res <- opas_request(path, auth = auth)
  
  if (is.null(res$statistics_results)) {
    rlang::abort(
      "Unexpected API response: missing `statistics_results` field.",
      class = "opas_api_error"
    )
  }
  
  # --- Parse ----------------------------------------------------------------
  
  df <- .opas_parse_statistics_results(res$statistics_results)
  
  if (nrow(df) == 0L) {
    rlang::warn(paste0(
      "API returned no statistics for this query. ",
      "Statistics are normally available only for completed years and ",
      "only where OPAS has computed annual results."
    ))
  }
  
  df
}


#' Retrieve OPAS annual statistics for a series
#'
#' Downloads pre-computed annual statistics for a single data series.
#' Compared to \code{\link{opas_get_station_stats}}, this endpoint targets
#' one specific parameter × station combination and returns all applicable
#' statistics and limits for that series.
#'
#' Only complete years are available; the current year returns no results
#' as statistics are computed at year-end.
#'
#' @param series_id Integer. Series identifier as returned by
#'   \code{\link{opas_series}} (\code{series_id} column).
#' @param year Integer or character. Four-digit year (e.g. \code{2025}).
#'   Must be a completed year.
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. Useful for process-based parallel workflows.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per statistic × limit
#'   combination. See \code{\link{opas_get_station_stats}} for a
#'   description of the columns; note that \code{parameter_id} is not
#'   returned by this endpoint.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' opas_get_series_stats(series_id = 12900, year = 2025)
#'
#' # Stateless authentication object
#' auth <- opas_auth("user@arpa.fvg.it", "my_password")
#' opas_get_series_stats(12900, 2025, auth = auth)
#' }
opas_get_series_stats <- function(series_id, year, auth = NULL) {
  
  # --- Input validation -----------------------------------------------------
  
  series_id <- suppressWarnings(as.integer(series_id))
  
  if (is.na(series_id)) {
    rlang::abort("`series_id` must be numeric.")
  }
  
  year <- .opas_validate_stats_year(year)
  
  path <- sprintf(
    "statistics-series-data/Y/%d/%d",
    series_id,
    year
  )
  
  # --- Request --------------------------------------------------------------
  
  res <- opas_request(path, auth = auth)
  
  if (is.null(res$statistics_results)) {
    rlang::abort(
      "Unexpected API response: missing `statistics_results` field.",
      class = "opas_api_error"
    )
  }
  
  # --- Parse ----------------------------------------------------------------
  
  df <- .opas_parse_statistics_results(res$statistics_results)
  
  if (nrow(df) == 0L) {
    rlang::warn(paste0(
      "API returned no statistics for this query. ",
      "Statistics are normally available only for completed years and ",
      "only where OPAS has computed annual results."
    ))
  }
  
  df
}