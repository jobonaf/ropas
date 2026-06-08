#' Get OPAS regulatory limits
#'
#' Retrieves the table of regulatory limit definitions used by the OPAS
#' system.  Each row defines a limit threshold and the maximum number of
#' allowed exceedances per year for a given pollutant statistic.
#'
#' This is a static reference table; it does not contain observed
#' exceedances.  For observed results against limits, use
#' \code{\link{opas_get_station_stats}} or \code{\link{opas_get_series_stats}}.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per limit definition:
#'   \describe{
#'     \item{limit_id}{Unique limit identifier; used as a foreign key in
#'       \code{\link{opas_statistics_limits}} and in statistics results.}
#'     \item{limit_description}{Human-readable description including
#'       pollutant, statistic type, threshold, and allowed exceedances.}
#'     \item{limit_threshold}{Numerical threshold value.}
#'     \item{limit_exceedances}{Maximum number of allowed exceedances per
#'       year; \code{NA} when no exceedance count applies.}
#'     \item{limit_unit}{Physical unit of the threshold.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' opas_limits()
#' }
opas_limits <- function() {
  
  res <- opas_request("limits")
  
  if (is.null(res$limits)) {
    rlang::abort(
      "Unexpected API response: missing `limits` field.",
      class = "opas_api_error"
    )
  }
  
  dplyr::bind_rows(res$limits)
}


#' Get OPAS statistic types
#'
#' Retrieves the table of statistic types defined in the OPAS system
#' (e.g. hourly mean, daily mean, annual mean).
#'
#' This is a static reference table.  For the mapping between statistics,
#' pollutants, and regulatory limits, use \code{\link{opas_statistics_limits}}.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per statistic type:
#'   \describe{
#'     \item{statistic_id}{Unique statistic identifier.}
#'     \item{statistic_description}{Human-readable description
#'       (e.g. \code{"Media"}, \code{"Media giornaliera"}).}
#'     \item{statistic_active}{Logical; whether the statistic is currently
#'       in use.}
#'     \item{statistic_order}{Display order.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' opas_statistics()
#' }
opas_statistics <- function() {
  
  res <- opas_request("statistics")
  
  if (is.null(res$statistics)) {
    rlang::abort(
      "Unexpected API response: missing `statistics` field.",
      class = "opas_api_error"
    )
  }
  
  dplyr::bind_rows(res$statistics)
}


#' Get OPAS statistic-pollutant-limit combinations
#'
#' Retrieves the full cross-reference table linking pollutants, statistic
#' types, and regulatory limits, including the temporal validity of each
#' limit.  This is the pre-joined version of \code{\link{opas_limits}} and
#' \code{\link{opas_statistics}}.
#'
#' Useful for understanding which limits apply to a given pollutant and
#' statistic, and for interpreting the \code{limit_id} column returned by
#' \code{\link{opas_get_station_stats}} and \code{\link{opas_get_series_stats}}.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per
#'   statistic × pollutant × limit combination:
#'   \describe{
#'     \item{stat_poll_id}{Unique identifier for the statistic-pollutant
#'       combination; foreign key in statistics results.}
#'     \item{stat_poll_type}{Aggregation period: \code{"D"} = daily,
#'       \code{"M"} = monthly, \code{"Y"} = annual.}
#'     \item{stat_poll_active}{Logical; whether this combination is active.}
#'     \item{pollutant_id, parameter_id, pollutant_name}{Pollutant
#'       identifiers.}
#'     \item{statistic_id, statistic_description, statistic_active}{
#'       Statistic type fields.}
#'     \item{limit_id, limit_description, limit_threshold,
#'       limit_exceedances, limit_unit}{Limit definition fields.}
#'     \item{limit_from, limit_to}{Temporal validity of the limit as
#'       character strings; \code{"-infinity"} and \code{"infinity"} are
#'       left as-is (not coercible to \code{Date}).}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' sl <- opas_statistics_limits()
#'
#' # Annual limits only
#' sl[sl$stat_poll_type == "Y", ]
#'
#' # All limits for NO2
#' sl[sl$pollutant_name == "NO2", ]
#' }
opas_statistics_limits <- function() {
  
  res <- opas_request("statistics-limits")
  
  if (is.null(res$statistic_limits)) {
    rlang::abort(
      "Unexpected API response: missing `statistic_limits` field.",
      class = "opas_api_error"
    )
  }
  
  dplyr::bind_rows(res$statistic_limits)
}