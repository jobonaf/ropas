#' Normalize an ISTAT region code
#'
#' Internal helper used by metadata and series endpoints.
#'
#' @param region Region code supplied by the user.
#'
#' @return Two-character ISTAT region code.
#'
#' @noRd
.opas_normalize_region <- function(region) {
  
  valid_regions <- sprintf("%02d", 1:20)
  
  region_norm <- suppressWarnings(sprintf("%02d", as.integer(region)))
  
  if (is.na(region_norm) || !region_norm %in% valid_regions) {
    rlang::abort(paste0(
      "`region` must be an ISTAT code between \"01\" and \"20\". ",
      "Got: \"", region, "\"."
    ))
  }
  
  region_norm
}


#' Safely rename columns
#'
#' Renames columns using a named character vector where names are the target
#' names and values are the source names. Missing source columns are ignored.
#'
#' This avoids failures from \code{dplyr::rename()} when OPAS returns
#' partial or empty responses.
#'
#' @param df Data frame or tibble.
#' @param map Named character vector, e.g.
#'   \code{c(station_id = "id", station_name = "name")}.
#'
#' @return Data frame or tibble with available columns renamed.
#'
#' @noRd
.opas_rename_cols <- function(df, map) {
  
  if (is.null(df) || length(map) == 0L) {
    return(df)
  }
  
  old <- unname(map)
  new <- names(map)
  
  present <- old %in% names(df)
  
  if (!any(present)) {
    return(df)
  }
  
  idx <- match(old[present], names(df))
  names(df)[idx] <- new[present]
  
  df
}


#' Convert a JSON object into a one-row tibble
#'
#' Internal helper for single-object OPAS endpoints. Scalar values are kept
#' as regular columns; non-scalar or nested values are preserved as
#' list-columns.
#'
#' @param x Named list returned by the API.
#'
#' @return A one-row tibble.
#'
#' @noRd
.opas_one_row_tibble <- function(x) {
  
  if (is.null(x) || length(x) == 0L) {
    return(tibble::tibble())
  }
  
  out <- lapply(x, function(v) {
    if (is.null(v)) {
      list(NULL)
    } else if (is.atomic(v) && length(v) == 1L) {
      v
    } else {
      list(v)
    }
  })
  
  tibble::as_tibble(out)
}


#' List OPAS monitoring stations
#'
#' Retrieves metadata for OPAS monitoring stations. Results can be
#' optionally filtered by ISTAT region code.
#'
#' The national catalogue is not large (a few hundred stations) and can be
#' downloaded without filtering.
#'
#' @param region Character or integer. ISTAT region code. Single-digit
#'   values are accepted and padded automatically, e.g. \code{6} or
#'   \code{"6"} become \code{"06"}. Valid values: \code{"01"}–\code{"20"}.
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. Useful for process-based parallel workflows.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per station.
#'   The \code{id} and \code{name} fields from the API are renamed to
#'   \code{station_id} and \code{station_name} for consistency with
#'   other package functions when present.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # All stations in Friuli-Venezia Giulia
#' opas_stations(region = "06")
#'
#' # Equivalent
#' opas_stations(region = 6)
#'
#' # All stations — national catalogue
#' opas_stations()
#' }
opas_stations <- function(region = NULL, auth = NULL) {
  
  if (!is.null(region)) {
    region <- .opas_normalize_region(region)
    path <- paste0("stations/", region)
  } else {
    path <- "stations"
  }
  
  res <- opas_request(path, auth = auth)
  
  if (is.null(res$stations)) {
    rlang::abort(
      "Unexpected API response: missing `stations` field.",
      class = "opas_api_error"
    )
  }
  
  out <- dplyr::bind_rows(res$stations)
  
  .opas_rename_cols(
    out,
    c(
      station_id   = "id",
      station_name = "name"
    )
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
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. Useful for process-based parallel workflows.
#'
#' @return A named list with two elements:
#'   \describe{
#'     \item{station}{A one-row \code{\link[tibble]{tibble}} with station
#'       metadata.}
#'     \item{parameters}{A \code{\link[tibble]{tibble}} with one row per
#'       parameter measured at the station. When present, fields are renamed
#'       consistently to \code{parameter_name}, \code{parameter_unit},
#'       \code{parameter_conv_curr}, and \code{parameter_conv_unit}.
#'       The \code{conversion_history} column is preserved as a list-column.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' det <- opas_station(1167)
#' det$station
#' det$parameters
#' }
opas_station <- function(station_id, auth = NULL) {
  
  station_id <- suppressWarnings(as.integer(station_id))
  
  if (is.na(station_id)) {
    rlang::abort("`station_id` must be numeric.")
  }
  
  path <- paste0("stations/", station_id)
  res  <- opas_request(path, auth = auth)
  
  if (is.null(res$station)) {
    rlang::abort(
      "Unexpected API response: missing `station` field.",
      class = "opas_api_error"
    )
  }
  
  raw <- res$station
  
  # Extract nested parameters before flattening the station row.
  params_raw <- raw$parameters
  raw$parameters <- NULL
  
  station_tbl <- .opas_one_row_tibble(raw)
  
  station_tbl <- .opas_rename_cols(
    station_tbl,
    c(
      station_id   = "id",
      station_name = "name"
    )
  )
  
  params_tbl <- if (!is.null(params_raw) && length(params_raw) > 0L) {
    dplyr::bind_rows(params_raw)
  } else {
    tibble::tibble()
  }
  
  params_tbl <- .opas_rename_cols(
    params_tbl,
    c(
      parameter_id        = "id",
      parameter_name      = "name",
      parameter_unit      = "unit",
      parameter_conv_curr = "conversion_factor_curr",
      parameter_conv_unit = "conversion_unit"
    )
  )
  
  list(
    station    = station_tbl,
    parameters = params_tbl
  )
}


#' List OPAS measured parameters
#'
#' Retrieves metadata for all parameters measured by OPAS stations,
#' including raw units, conversion factors, reporting units, and aggregation
#' settings.
#'
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. Useful for process-based parallel workflows.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per parameter.
#'   Key columns:
#'   \describe{
#'     \item{parameter_id}{Unique parameter identifier.}
#'     \item{parameter_name}{Human-readable parameter name, e.g.
#'       \code{"NO2"}.}
#'     \item{parameter_unit}{Raw measurement unit used by the instrument,
#'       e.g. \code{"ppb"}.}
#'     \item{parameter_conv_curr}{Current conversion factor used to
#'       transform raw measurements into the reporting unit.}
#'     \item{parameter_conv_unit}{Reporting unit after applying
#'       \code{parameter_conv_curr}, e.g. \code{"µg/m³"}.}
#'     \item{conversion_history}{List-column with historical conversion
#'       factors; relevant for long time series spanning conversion changes.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' params <- opas_parameters()
#' params[, c("parameter_id", "parameter_name", "parameter_unit",
#'            "parameter_conv_curr", "parameter_conv_unit")]
#' }
opas_parameters <- function(auth = NULL) {
  
  res <- opas_request("parameters", auth = auth)
  
  if (is.null(res$parameters)) {
    rlang::abort(
      "Unexpected API response: missing `parameters` field.",
      class = "opas_api_error"
    )
  }
  
  out <- dplyr::bind_rows(res$parameters)
  
  .opas_rename_cols(
    out,
    c(
      parameter_id        = "id",
      parameter_name      = "name",
      parameter_unit      = "unit",
      parameter_conv_curr = "conversion_factor_curr",
      parameter_conv_unit = "conversion_unit"
    )
  )
}


#' Get detailed metadata for a single OPAS parameter
#'
#' Retrieves full metadata for one parameter by ID, including raw unit,
#' conversion factor, reporting unit, aggregation settings, and conversion
#' history.
#'
#' @param parameter_id Integer. Parameter identifier as returned by the
#'   \code{parameter_id} column of \code{\link{opas_parameters}}.
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. Useful for process-based parallel workflows.
#'
#' @return A one-row \code{\link[tibble]{tibble}} with all parameter fields.
#'   \code{conversion_history} is preserved as a list-column;
#'   \code{date_from}/\code{date_to} entries of \code{"-infinity"} and
#'   \code{"infinity"} are left as character strings.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' opas_parameter(7)   # Pressione
#' opas_parameter(29)  # SO2
#' }
opas_parameter <- function(parameter_id, auth = NULL) {
  
  parameter_id <- suppressWarnings(as.integer(parameter_id))
  
  if (is.na(parameter_id)) {
    rlang::abort("`parameter_id` must be numeric.")
  }
  
  path <- paste0("parameters/", parameter_id)
  res  <- opas_request(path, auth = auth)
  
  if (is.null(res$parameter)) {
    rlang::abort(
      "Unexpected API response: missing `parameter` field.",
      class = "opas_api_error"
    )
  }
  
  out <- .opas_one_row_tibble(res$parameter)
  
  .opas_rename_cols(
    out,
    c(
      parameter_id        = "id",
      parameter_name      = "name",
      parameter_unit      = "unit",
      parameter_conv_curr = "conversion_factor_curr",
      parameter_conv_unit = "conversion_unit"
    )
  )
}


#' List OPAS parameter types
#'
#' Retrieves the classification of parameters into categories
#' (e.g. \emph{Chimici}, \emph{Meteo}). Useful for filtering the output of
#' \code{\link{opas_parameters}} by category.
#'
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. Useful for process-based parallel workflows.
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
opas_parameter_types <- function(auth = NULL) {
  
  res <- opas_request("parameters-type", auth = auth)
  
  if (is.null(res$parameters_type)) {
    rlang::abort(
      "Unexpected API response: missing `parameters_type` field.",
      class = "opas_api_error"
    )
  }
  
  dplyr::bind_rows(res$parameters_type)
}