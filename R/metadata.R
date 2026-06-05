#' List OPAS monitoring stations
#'
#' Retrieves metadata for OPAS monitoring stations.  Results can be
#' optionally filtered by ISTAT region code.
#'
#' The national catalogue is not large (a few hundred stations) and can be
#' downloaded without filtering.
#'
#' @param region Character. ISTAT region code, zero-padded to two digits.
#'   Single-digit values are accepted and padded automatically
#'   (e.g. \code{"6"} -> \code{"06"}).  Valid values: \code{"01"}–\code{"20"}.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per station.
#'   The \code{id} and \code{name} fields from the API are renamed to
#'   \code{station_id} and \code{station_name} for consistency with
#'   other package functions.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # All stations in Friuli-Venezia Giulia
#' opas_stations(region = "06")
#'
#' # All stations — national catalogue
#' opas_stations()
#' }
opas_stations <- function(region = NULL) {
  
  valid_regions <- sprintf("%02d", 1:20)
  
  if (!is.null(region)) {
    region <- sprintf("%02d", as.integer(region))
    if (!region %in% valid_regions) {
      rlang::abort(paste0(
        "`region` must be a two-digit ISTAT code between \"01\" and \"20\". ",
        "Got: \"", region, "\"."
      ))
    }
    path <- paste0("stations/", region)
  } else {
    path <- "stations"
  }
  
  res <- opas_request(path)
  
  if (is.null(res$stations)) {
    rlang::abort(
      "Unexpected API response: missing `stations` field.",
      class = "opas_api_error"
    )
  }
  
  dplyr::bind_rows(res$stations) |>
    dplyr::rename(
      station_id   = id,
      station_name = name
    )
}


#' List OPAS measured parameters
#'
#' Retrieves metadata for all parameters measured by OPAS stations,
#' including physical units, conversion factors, and aggregation settings.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per parameter.
#'   Key columns:
#'   \describe{
#'     \item{parameter_id}{Unique parameter identifier.}
#'     \item{parameter_name}{Human-readable parameter name (e.g. \code{"NO2"}).}
#'     \item{parameter_unit}{Raw measurement unit as provided by the instrument
#'       (e.g. \code{"ppb"}).}
#'     \item{conversion_unit}{Target unit after applying the conversion factor
#'       (e.g. \code{"µg/m³"}).}
#'     \item{parameter_conv_curr}{Current conversion factor.  Multiply
#'       \code{value_raw} from \code{\link{opas_get_series_data_raw}} by this
#'       value to obtain measurements in \code{parameter_unit}.}
#'     \item{conversion_history}{List-column with historical conversion
#'       factors; relevant for long time series spanning unit changes.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' params <- opas_parameters()
#' params[, c("parameter_id", "parameter_name", "parameter_unit",
#'            "parameter_conv_curr")]
#' }
opas_parameters <- function() {
  
  res <- opas_request("parameters")
  
  if (is.null(res$parameters)) {
    rlang::abort(
      "Unexpected API response: missing `parameters` field.",
      class = "opas_api_error"
    )
  }
  
  dplyr::bind_rows(res$parameters) |>
    dplyr::rename(
      parameter_id        = id,
      parameter_name      = name,
      parameter_unit      = unit,
      parameter_conv_curr = conversion_factor_curr,
      parameter_conv_unit = conversion_unit
    )
}


#' List OPAS parameter types
#'
#' Retrieves the classification of parameters into categories
#' (e.g. \emph{Chimici}, \emph{Meteo}).  Useful for filtering the output of
#' \code{\link{opas_parameters}} by category.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per parameter type,
#'   containing at minimum a type identifier and a description.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' opas_parameter_types()
#' }
opas_parameter_types <- function() {
  
  res <- opas_request("parameters-type")
  
  if (is.null(res$parameters_type)) {
    rlang::abort(
      "Unexpected API response: missing `parameters_type` field.",
      class = "opas_api_error"
    )
  }
  
  dplyr::bind_rows(res$parameters_type)
}