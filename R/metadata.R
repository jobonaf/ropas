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


#' Convert a datetime value to ISO 8601 string
#'
#' Internal helper used by endpoints that accept ISO 8601 timestamps in the
#' URL path. POSIXct input is formatted as Italian standard time
#' (UTC+1 fixed, no daylight saving).
#'
#' @param x POSIXct or character.
#' @param arg Character scalar. Argument name used in error messages.
#'
#' @return Character scalar in format "YYYY-MM-DDTHH:MM:SS".
#'
#' @noRd
.opas_datetime_to_iso <- function(x, arg = "at") {
  
  if (inherits(x, "POSIXct")) {
    return(format(x, "%Y-%m-%dT%H:%M:%S", tz = "Etc/GMT-1"))
  }
  
  x_chr <- as.character(x)
  
  pattern <- "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$"
  
  if (length(x_chr) != 1L || is.na(x_chr) || !grepl(pattern, x_chr)) {
    rlang::abort(paste0(
      "`", arg, "` must be a POSIXct or ISO 8601 string ",
      "(\"YYYY-MM-DDTHH:MM:SS\"). Got: ", x
    ))
  }
  
  x_chr
}


#' List OPAS monitoring sites
#'
#' Retrieves the table of OPAS monitoring sites.
#'
#' Sites represent physical locations where stations may be allocated,
#' including geographic coordinates and associated network names.
#'
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. Useful for process-based parallel workflows.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per site.
#'   Key columns:
#'   \describe{
#'     \item{site_id}{Unique site identifier.}
#'     \item{site_name}{Site name.}
#'     \item{wgs84_lat, wgs84_lon}{Geographic coordinates.}
#'     \item{altitude}{Site altitude.}
#'     \item{municipality_name, province_name, region_name}{
#'       Administrative location fields.}
#'     \item{network_names}{List-column with network names associated with
#'       the site.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' sites <- opas_sites()
#'
#' auth <- opas_auth("user@arpa.fvg.it", "my_password")
#' sites <- opas_sites(auth = auth)
#' }
opas_sites <- function(auth = NULL) {
  
  res <- opas_request("sites", auth = auth)
  
  out <- .opas_parse_lookup_table(
    x = res$sites,
    field = "sites"
  )
  
  .opas_rename_cols(
    out,
    c(
      site_id   = "id",
      site_name = "name"
    )
  )
}


#' Retrieve OPAS station campaign allocations
#'
#' Retrieves campaign allocation metadata for a station. If \code{at} is
#' supplied, only campaigns active at that date-time are returned.
#'
#' @param station_id Integer. Station identifier as returned by
#'   \code{\link{opas_stations}}.
#' @param at Optional date-time used to filter active campaigns. Accepted
#'   inputs are:
#'   \itemize{
#'     \item A \code{POSIXct} object.
#'     \item A character string in ISO 8601 format
#'       \code{"YYYY-MM-DDTHH:MM:SS"}, interpreted as UTC+1 fixed
#'       (\code{"Etc/GMT-1"}).
#'   }
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. Useful for process-based parallel workflows.
#'
#' @return A \code{\link[tibble]{tibble}} with one row per allocation,
#'   or an empty tibble if no campaigns are available for the query.
#'   Key columns:
#'   \describe{
#'     \item{station_id, station_name}{Station identifiers.}
#'     \item{station_override_id, station_external_id}{Additional station
#'       identifiers returned by the API.}
#'     \item{site_id, site_name}{Site identifiers.}
#'     \item{site_locality}{Site locality.}
#'     \item{site_wgs84_lat, site_wgs84_lon}{Site coordinates.}
#'     \item{allocation_startup_date, allocation_dismiss_date}{
#'       Allocation period as \code{POSIXct} in UTC+1 fixed
#'       (\code{"Etc/GMT-1"}), when returned by the API.}
#'     \item{network_names}{List-column with network names.}
#'     \item{...}{Additional allocation or campaign fields returned by the
#'       API, such as \code{campaign_id} and \code{campaign_name} when
#'       available.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # All campaigns for a station
#' opas_campaigns(1167)
#'
#' # Campaigns active at a specific date-time
#' opas_campaigns(1167, at = "2026-06-01T00:00:00")
#'
#' auth <- opas_auth("user@arpa.fvg.it", "my_password")
#' opas_campaigns(1167, auth = auth)
#' }
opas_campaigns <- function(station_id, at = NULL, auth = NULL) {
  
  station_id <- suppressWarnings(as.integer(station_id))
  
  if (is.na(station_id)) {
    rlang::abort("`station_id` must be numeric.")
  }
  
  if (is.null(at)) {
    path <- sprintf("campaigns/%d", station_id)
  } else {
    at_iso <- .opas_datetime_to_iso(at, arg = "at")
    path <- sprintf("campaigns/%d/%s", station_id, at_iso)
  }
  
  res <- opas_request(path, auth = auth)
  
  if (!"allocations" %in% names(res)) {
    rlang::abort(
      "Unexpected API response: missing `allocations` field.",
      class = "opas_api_error"
    )
  }
  
  if (is.null(res$allocations) || length(res$allocations) == 0L) {
    rlang::warn("API returned no campaign allocations for this query.")
    return(tibble::tibble())
  }
  
  out <- dplyr::bind_rows(res$allocations)
  
  out <- .opas_parse_datetime_column(
    out,
    col = "allocation_startup_date",
    tz = "Etc/GMT-1",
    truncate = FALSE
  )
  
  out <- .opas_parse_datetime_column(
    out,
    col = "allocation_dismiss_date",
    tz = "Etc/GMT-1",
    truncate = FALSE
  )
  
  out
}

#' Retrieve station parameters for a specific OPAS station and parameter
#'
#' Retrieves detailed station metadata and the corresponding parameter
#' series metadata for a given station-parameter combination.
#'
#' The returned structure is intentionally consistent with
#' \code{\link{opas_station}}: a named list with a one-row station tibble
#' and a parameter-series tibble.
#'
#' @param station_id Integer. Station identifier as returned by
#'   \code{\link{opas_stations}}.
#' @param parameter_id Integer. Parameter identifier as returned by
#'   \code{\link{opas_parameters}}.
#' @param auth Optional object returned by \code{\link{opas_auth}}.
#'   If supplied, it is used instead of the package-global authentication
#'   state. Useful for process-based parallel workflows.
#'
#' @return A named list with two elements:
#'   \describe{
#'     \item{station}{A one-row \code{\link[tibble]{tibble}} with station
#'       metadata.}
#'     \item{parameters}{A \code{\link[tibble]{tibble}} with one row per
#'       matching parameter series. Key columns include \code{series_id},
#'       \code{parameter_id}, \code{parameter_name}, \code{parameter_unit},
#'       \code{parameter_conv_curr}, and \code{parameter_conv_unit}.
#'       \code{conversion_history} is preserved as a list-column.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' opas_station_parameters(station_id = 1167, parameter_id = 34)
#'
#' auth <- opas_auth("user@arpa.fvg.it", "my_password")
#' opas_station_parameters(1167, 34, auth = auth)
#' }
opas_station_parameters <- function(station_id, parameter_id, auth = NULL) {
  
  station_id <- suppressWarnings(as.integer(station_id))
  if (is.na(station_id)) {
    rlang::abort("`station_id` must be numeric.")
  }
  
  parameter_id <- suppressWarnings(as.integer(parameter_id))
  if (is.na(parameter_id)) {
    rlang::abort("`parameter_id` must be numeric.")
  }
  
  path <- sprintf(
    "stations-parameters/%d/%d",
    station_id,
    parameter_id
  )
  
  res <- opas_request(path, auth = auth)
  
  if (is.null(res$station)) {
    rlang::abort(
      "Unexpected API response: missing `station` field.",
      class = "opas_api_error"
    )
  }
  
  raw <- res$station
  
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
      parameter_id          = "id",
      parameter_external_id = "external_id",
      parameter_name        = "name",
      parameter_unit        = "unit",
      parameter_conv_curr   = "conversion_factor_curr",
      parameter_conv_unit   = "conversion_unit"
    )
  )
  
  list(
    station    = station_tbl,
    parameters = params_tbl
  )
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