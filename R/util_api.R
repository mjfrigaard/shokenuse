#' Fetch token usage from the Anthropic Admin API
#'
#' Calls `GET /v1/organizations/usage_report/messages`. Handles pagination
#' automatically. Requires an Admin API key from an organization account —
#' not available for individual (personal) accounts.
#'
#' @param starting_at Start of window (POSIXct or ISO-8601 string).
#' @param ending_at End of window. Defaults to current time.
#' @param bucket_width Aggregation interval: `"1d"`, `"1h"`, or `"1m"`.
#' @param group_by Character vector of dimensions to group by. Valid values:
#'   `"model"`, `"workspace_id"`, `"api_key_id"`, `"service_tier"`,
#'   `"inference_geo"`.
#' @param models Character vector of model names to filter; empty = all.
#' @param api_key Admin API key. Defaults to `ANTHROPIC_ADMIN_KEY` env var.
#' @param max_pages Maximum pagination pages to fetch (safety cap).
#' @return Tibble with `timestamp_bucket`, `bucket_width`, any `group_by`
#'   columns, `input_tokens`, `output_tokens`, `cache_creation_input_tokens`,
#'   `cache_read_input_tokens`, `n_requests`.
#' @export
util_fetch_usage <- function(
    starting_at,
    ending_at    = Sys.time(),
    bucket_width = c("1d", "1h", "1m"),
    group_by     = character(),
    models       = character(),
    api_key      = Sys.getenv("ANTHROPIC_ADMIN_KEY"),
    max_pages    = 10L) {

  bucket_width <- match.arg(bucket_width)
  .require_api_key(api_key)

  start_fmt <- .fmt_datetime(starting_at)
  end_fmt   <- .fmt_datetime(ending_at)

  logger::log_info(
    "Fetching usage: {start_fmt} -> {end_fmt} [bucket={bucket_width}]",
    namespace = "shokenuse"
  )
  if (length(group_by) > 0) {
    logger::log_debug(
      "Group by: {paste(group_by, collapse = ', ')}",
      namespace = "shokenuse"
    )
  }
  if (length(models) > 0) {
    logger::log_debug(
      "Model filter: {paste(models, collapse = ', ')}",
      namespace = "shokenuse"
    )
  }

  base_url <- "https://api.anthropic.com/v1/organizations/usage_report/messages"

  params <- list(
    starting_at  = start_fmt,
    ending_at    = end_fmt,
    bucket_width = bucket_width
  )

  params <- c(params,
    setNames(as.list(group_by), rep("group_by[]", length(group_by))),
    setNames(as.list(models),   rep("models[]",   length(models)))
  )

  results <- tryCatch(
    .paginate_api(base_url, params, api_key, max_pages),
    error = function(e) {
      logger::log_error(
        "Usage API request failed: {conditionMessage(e)}",
        namespace = "shokenuse"
      )
      rlang::abort(
        paste("util_fetch_usage failed:", conditionMessage(e)),
        parent = e
      )
    }
  )

  tbl <- .parse_usage_response(results)
  logger::log_info(
    "Fetched {nrow(tbl)} usage record(s)",
    namespace = "shokenuse"
  )
  tbl
}


#' Fetch cost data from the Anthropic Admin API
#'
#' Calls `GET /v1/organizations/cost_report` (daily granularity only).
#' Requires an Admin API key from an organization account.
#'
#' @param starting_at Start of window (POSIXct or ISO-8601 string).
#' @param ending_at End of window. Defaults to current time.
#' @param group_by Character vector of grouping dimensions: `"workspace_id"`,
#'   `"description"`.
#' @param api_key Admin API key. Defaults to `ANTHROPIC_ADMIN_KEY` env var.
#' @param max_pages Maximum pagination pages to fetch.
#' @return Tibble with cost data in USD.
#' @export
util_fetch_cost <- function(
    starting_at,
    ending_at = Sys.time(),
    group_by  = character(),
    api_key   = Sys.getenv("ANTHROPIC_ADMIN_KEY"),
    max_pages = 10L) {

  .require_api_key(api_key)

  start_fmt <- .fmt_datetime(starting_at)
  end_fmt   <- .fmt_datetime(ending_at)

  logger::log_info(
    "Fetching costs: {start_fmt} -> {end_fmt}",
    namespace = "shokenuse"
  )
  if (length(group_by) > 0) {
    logger::log_debug(
      "Group by: {paste(group_by, collapse = ', ')}",
      namespace = "shokenuse"
    )
  }

  base_url <- "https://api.anthropic.com/v1/organizations/cost_report"

  params <- list(
    starting_at  = start_fmt,
    ending_at    = end_fmt,
    bucket_width = "1d"
  )

  params <- c(params,
    setNames(as.list(group_by), rep("group_by[]", length(group_by)))
  )

  results <- tryCatch(
    .paginate_api(base_url, params, api_key, max_pages),
    error = function(e) {
      logger::log_error(
        "Cost API request failed: {conditionMessage(e)}",
        namespace = "shokenuse"
      )
      rlang::abort(
        paste("util_fetch_cost failed:", conditionMessage(e)),
        parent = e
      )
    }
  )

  tbl <- .parse_cost_response(results)
  logger::log_info(
    "Fetched {nrow(tbl)} cost record(s)",
    namespace = "shokenuse"
  )
  tbl
}


# ── Internal helpers ──────────────────────────────────────────────────────────

.require_api_key <- function(key) {
  if (!nzchar(key)) {
    logger::log_error(
      "Admin API key is missing or empty",
      namespace = "shokenuse"
    )
    rlang::abort(
      paste0(
        "Admin API key required. ",
        "Set the ANTHROPIC_ADMIN_KEY environment variable or pass `api_key`."
      )
    )
  }
}


.fmt_datetime <- function(x) {
  x <- as.POSIXct(x, tz = "UTC")
  format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}


.api_get <- function(url, params, api_key) {
  logger::log_debug("GET {url}", namespace = "shokenuse")

  req <- httr2::request(url) |>
    httr2::req_headers(
      "anthropic-version" = "2023-06-01",
      "x-api-key"         = api_key
    )

  for (nm in names(params)) {
    val <- params[[nm]]
    req <- httr2::req_url_query(req, !!nm := val)
  }

  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) {
      logger::log_error(
        "HTTP request to {url} failed: {conditionMessage(e)}",
        namespace = "shokenuse"
      )
      rlang::abort(
        paste("API request failed:", conditionMessage(e)),
        parent = e
      )
    }
  )

  status <- httr2::resp_status(resp)
  logger::log_debug("Response: HTTP {status}", namespace = "shokenuse")

  if (status >= 400L) {
    body_text <- tryCatch(
      httr2::resp_body_string(resp),
      error = function(e) "<unreadable body>"
    )
    logger::log_error(
      "API returned HTTP {status}: {body_text}",
      namespace = "shokenuse"
    )
    rlang::abort(paste0("API returned HTTP ", status, ": ", body_text))
  }

  httr2::resp_body_json(resp, simplifyVector = FALSE)
}


.paginate_api <- function(base_url, params, api_key, max_pages) {
  all_results <- list()
  page_token  <- NULL
  page_count  <- 0L

  repeat {
    page_count <- page_count + 1L
    logger::log_debug(
      "Fetching page {page_count} (max {max_pages})",
      namespace = "shokenuse"
    )

    if (page_count > max_pages) {
      logger::log_warn(
        "Reached max_pages limit ({max_pages}); stopping pagination early",
        namespace = "shokenuse"
      )
      break
    }

    current_params <- params
    if (!is.null(page_token)) {
      current_params[["page"]] <- page_token
    }

    body        <- .api_get(base_url, current_params, api_key)
    all_results <- c(all_results, body[["results"]] %||% list())

    if (!isTRUE(body[["has_more"]])) break
    page_token <- body[["next_page"]]
    if (is.null(page_token)) break
  }

  logger::log_info(
    "Pagination complete: {page_count} page(s), {length(all_results)} result(s)",
    namespace = "shokenuse"
  )
  all_results
}


.parse_usage_response <- function(results) {
  if (length(results) == 0) {
    return(tibble::tibble(
      timestamp_bucket            = character(),
      input_tokens                = integer(),
      output_tokens               = integer(),
      cache_creation_input_tokens = integer(),
      cache_read_input_tokens     = integer(),
      n_requests                  = integer()
    ))
  }

  rows <- lapply(results, function(r) {
    tibble::tibble(
      timestamp_bucket            = r[["timestamp_bucket"]]                        %||% NA_character_,
      input_tokens                = as.integer(r[["input_tokens"]]                 %||% 0L),
      output_tokens               = as.integer(r[["output_tokens"]]                %||% 0L),
      cache_creation_input_tokens = as.integer(r[["cache_creation_input_tokens"]]  %||% 0L),
      cache_read_input_tokens     = as.integer(r[["cache_read_input_tokens"]]      %||% 0L),
      n_requests                  = as.integer(r[["n_requests"]]                   %||% 0L),
      model                       = r[["model"]]                                   %||% NA_character_,
      workspace_id                = r[["workspace_id"]]                            %||% NA_character_,
      api_key_id                  = r[["api_key_id"]]                              %||% NA_character_,
      service_tier                = r[["service_tier"]]                            %||% NA_character_,
      inference_geo               = r[["inference_geo"]]                           %||% NA_character_
    )
  })

  result <- dplyr::bind_rows(rows)

  optional_cols <- c("model", "workspace_id", "api_key_id", "service_tier", "inference_geo")
  all_na <- vapply(optional_cols, function(col) all(is.na(result[[col]])), logical(1))
  result[, !names(result) %in% optional_cols[all_na]]
}


.parse_cost_response <- function(results) {
  if (length(results) == 0) {
    return(tibble::tibble(
      timestamp_bucket = character(),
      cost_usd         = numeric()
    ))
  }

  rows <- lapply(results, function(r) {
    tibble::tibble(
      timestamp_bucket = r[["timestamp_bucket"]] %||% NA_character_,
      cost_usd         = as.numeric(r[["cost"]]  %||% 0),
      workspace_id     = r[["workspace_id"]]     %||% NA_character_,
      description      = r[["description"]]      %||% NA_character_
    )
  })

  result <- dplyr::bind_rows(rows)
  optional_cols <- c("workspace_id", "description")
  all_na <- vapply(optional_cols, function(col) all(is.na(result[[col]])), logical(1))
  result[, !names(result) %in% optional_cols[all_na]]
}
