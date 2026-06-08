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


#' Get detailed metadata for a single OPAS station
#'
#' Retrieves full metadata for one station by ID, including the list of all
#' parameters (data series) currently or historically measured at that
#' station.
#'
#' @param station_id Integer. Station identifier as returned by the
#'   \code{station_id} column of \code{\link{opas_stations}}.
#'
#' @return A named list with two elements:
#'   \describe{
#'     \item{station}{A one-row \code{\link[tibble]{tibble}} with station
#'       metadata (identifiers, location, classification, network).}
#'     \item{parameters}{A \code{\link[tibble]{tibble}} with one row per
#'       parameter measured at the station, including \code{series_id},
#'       \code{name}, \code{unit}, \code{conversion_factor_curr}, and
#'       \code{active}.  The \code{conversion_history} column is a
#'       list-column; \code{date_from}/\code{date_to} values of
#'       \code{"-infinity"} and \code{"infinity"} are left as-is (they
#'       cannot be coerced to \code{Date}).}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' det <- opas_station(1167)
#' det$station    # one-row tibble with location etc.
#' det$parameters # all series measured at this station
#' }
opas_station <- function(station_id) {
  
  path <- paste0("stations/", as.integer(station_id))
  res  <- opas_request(path)
  
  if (is.null(res$station)) {
    rlang::abort(
      "Unexpected API response: missing `station` field.",
      class = "opas_api_error"
    )
  }
  
  raw <- res$station
  
  # Extract the nested parameters list before flattening the station row.
  params_raw <- raw$parameters
  raw$parameters <- NULL
  
  # Station scalar fields -> one-row tibble.
  station_tbl <- tibble::as_tibble(raw) |>
    dplyr::rename(
      station_id   = id,
      station_name = name
    )
  
  # Parameters -> one row per series; conversion_history kept as list-column.
  params_tbl <- if (!is.null(params_raw) && length(params_raw) > 0L) {
    dplyr::bind_rows(params_raw)
  } else {
    tibble::tibble()
  }
  
  list(
    station    = station_tbl,
    parameters = params_tbl
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
#'     \item{parameter_unit}{Physical unit after conversion
#'       (e.g. \code{"µg/m³"}).}
#'     \item{parameter_conv_curr}{Current conversion factor.  Multiply
#'       \code{value_raw} from \code{\link{opas_get_data}} by this
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
      parameter_conv_curr = conversion_factor_curr
    )
}


#' Get detailed metadata for a single OPAS parameter
#'
#' Retrieves full metadata for one parameter by ID, including unit,
#' conversion factor, aggregation settings, and conversion history.
#'
#' @param parameter_id Integer. Parameter identifier as returned by the
#'   \code{parameter_id} column of \code{\link{opas_parameters}}.
#'
#' @return A one-row \code{\link[tibble]{tibble}} with all parameter fields.
#'   \code{conversion_history} is a list-column; \code{date_from}/\code{date_to}
#'   entries of \code{"-infinity"} and \code{"infinity"} are left as
#'   character strings.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' opas_parameter(7)   # Pressione
#' opas_parameter(29)  # SO2
#' }
opas_parameter <- function(parameter_id) {
  
  path <- paste0("parameters/", as.integer(parameter_id))
  res  <- opas_request(path)
  
  if (is.null(res$parameter)) {
    rlang::abort(
      "Unexpected API response: missing `parameter` field.",
      class = "opas_api_error"
    )
  }
  
  # conversion_history is a list-column; tibble() handles it automatically.
  tibble::as_tibble(res$parameter) |>
    dplyr::rename(
      parameter_id        = id,
      parameter_name      = name,
      parameter_unit      = unit,
      parameter_conv_curr = conversion_factor_curr
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