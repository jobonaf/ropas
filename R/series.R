#' List available OPAS data series
#'
#' Retrieves the catalogue of data series from the OPAS API.  Each series
#' corresponds to one parameter measured at one station, and carries the
#' \code{series_id} needed to download actual measurements via
#' \code{\link{opas_get_data}}.
#'
#' Exactly one of \code{region} or \code{station} should normally be
#' supplied.  Calling the function with no arguments fetches the full
#' national catalogue, which is a very large object; a confirmation prompt
#' is shown in interactive sessions.
#'
#' @param region  Character. ISTAT region code, zero-padded to two digits
#'   (e.g. \code{"06"} for Friuli-Venezia Giulia).  Valid values:
#'   \code{"01"}–\code{"20"}.
#' @param station Integer or character. Station ID as returned by the
#'   \code{id} field of \code{/stations}.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per series and the
#'   following key columns:
#'   \describe{
#'     \item{series_id}{Unique series identifier; use this with
#'       \code{\link{opas_get_data}}.}
#'     \item{station_id, station_name}{Station identifiers.}
#'     \item{parameter_id, parameter_name, parameter_unit}{Parameter
#'       identifiers and physical unit.}
#'     \item{parameter_conv_curr}{Current conversion factor; raw
#'       \code{measure_value} from \code{/series-data} must be multiplied
#'       by this to obtain values in \code{parameter_unit}.}
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
#' # All series for a specific station
#' opas_series(station = 1167)
#' }
opas_series <- function(region = NULL, station = NULL) {
  
  # --- Input validation -----------------------------------------------------
  
  if (!is.null(region) && !is.null(station)) {
    rlang::abort("Provide only one of `region` or `station`, not both.")
  }
  
  valid_regions <- sprintf("%02d", 1:20)
  
  if (!is.null(region)) {
    region <- as.character(region)
    if (!region %in% valid_regions) {
      rlang::abort(paste0(
        "`region` must be a two-digit ISTAT code between \"01\" and \"20\". ",
        "Got: \"", region, "\"."
      ))
    }
    path <- paste0("series/", region)
    
  } else if (!is.null(station)) {
    path <- paste0("series/", as.integer(station))
    
  } else {
    # No filter: national catalogue, very large (~MB range).
    # In interactive sessions, ask for confirmation.
    if (interactive()) {
      msg <- paste0(
        "Fetching the full series catalogue returns a very large dataset ",
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
        "fetching the full national series catalogue. ",
        "This may be very slow."
      ))
    }
    path <- "series"
  }
  
  # --- Request --------------------------------------------------------------
  
  res <- opas_request(path)
  
  if (is.null(res$series)) {
    rlang::abort(
      "Unexpected API response: missing `series` field.",
      class = "opas_api_error"
    )
  }
  
  # --- Parse ----------------------------------------------------------------
  # opas_request() returns simplifyVector = FALSE, so res$series is a list
  # of lists; bind_rows() flattens it into a tibble.  List-columns such as
  # parameter_conv_history are preserved as list-columns.
  dplyr::bind_rows(res$series)
}