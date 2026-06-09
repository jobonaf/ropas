#' List available OPAS data series
#'
#' Retrieves the catalogue of data series from the OPAS API. Each series
#' corresponds to one parameter measured at one station, and carries the
#' \code{series_id} needed to download measurements via
#' \code{\link{opas_get_data}}.
#'
#' Exactly one of \code{region} or \code{station} should normally be
#' supplied. Calling the function with no arguments fetches the full
#' catalogue, which can be a large object; a confirmation prompt is shown
#' in interactive sessions.
#'
#' @param region Character or integer. ISTAT region code. Single-digit
#'   values are accepted and padded automatically, e.g. \code{6} or
#'   \code{"6"} become \code{"06"}. Valid values: \code{"01"}–\code{"20"}.
#' @param station Integer or character. Station ID as returned by the
#'   \code{station_id} column of \code{\link{opas_stations}}.
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. Useful for process-based parallel workflows.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per series.
#'   Key columns include:
#'   \describe{
#'     \item{series_id}{Unique series identifier; use this with
#'       \code{\link{opas_get_data}}.}
#'     \item{station_id, station_name}{Station identifiers.}
#'     \item{parameter_id, parameter_name}{Parameter identifiers.}
#'     \item{parameter_unit}{Raw measurement unit, e.g. \code{"ppb"}.}
#'     \item{parameter_conv_curr}{Current conversion factor used to
#'       transform raw measurements into the reporting unit.}
#'     \item{parameter_conv_unit}{Reporting unit after applying
#'       \code{parameter_conv_curr}, e.g. \code{"µg/m³"}.}
#'     \item{region_istat_code, region_name}{Region identifiers.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # All series for Friuli-Venezia Giulia
#' opas_series(region = "06")
#'
#' # Equivalent
#' opas_series(region = 6)
#'
#' # All series for a specific station
#' opas_series(station = 1167)
#'
#' # Stateless authentication object
#' auth <- opas_auth("user@arpa.fvg.it", "my_password")
#' opas_series(region = "06", auth = auth)
#' }
opas_series <- function(region = NULL, station = NULL, auth = NULL) {
  
  # --- Input validation -----------------------------------------------------
  
  if (!is.null(region) && !is.null(station)) {
    rlang::abort("Provide only one of `region` or `station`, not both.")
  }
  
  if (!is.null(region)) {
    
    region <- .opas_normalize_region(region)
    path <- paste0("series/", region)
    
  } else if (!is.null(station)) {
    
    station <- suppressWarnings(as.integer(station))
    
    if (is.na(station)) {
      rlang::abort("`station` must be numeric.")
    }
    
    path <- paste0("series/", station)
    
  } else {
    
    # No filter: full catalogue, potentially large.
    # In interactive sessions, ask for confirmation.
    if (interactive()) {
      msg <- paste0(
        "Fetching the full series catalogue can return a large dataset ",
        "(all stations, all regions).\n",
        "Use `region` or `station` to restrict the query.\n",
        "Continue anyway? [y/N] "
      )
      
      ans <- readline(msg)
      
      if (!tolower(trimws(ans)) %in% c("y", "yes")) {
        message("Aborted.")
        return(invisible(NULL))
      }
      
    } else {
      rlang::warn(paste0(
        "opas_series() called without `region` or `station`: ",
        "fetching the full series catalogue. ",
        "This may be slow."
      ))
    }
    
    path <- "series"
  }
  
  # --- Request --------------------------------------------------------------
  
  res <- opas_request(path, auth = auth)
  
  if (is.null(res$series)) {
    rlang::abort(
      "Unexpected API response: missing `series` field.",
      class = "opas_api_error"
    )
  }
  
  # --- Parse ----------------------------------------------------------------
  # opas_request() returns simplifyVector = FALSE, so res$series is a list
  # of lists; bind_rows() flattens it into a tibble. List-columns such as
  # parameter_conv_history are preserved as list-columns.
  
  out <- dplyr::bind_rows(res$series)
  
  # Standardise conversion-unit naming if the API returns the unprefixed
  # field name. Missing source columns are ignored by .opas_rename_cols().
  out <- .opas_rename_cols(
    out,
    c(
      parameter_conv_unit = "conversion_unit"
    )
  )
  
  out
}
