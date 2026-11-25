# ── Null-coalesce operator ─────────────────────────────────────────────────────

`%||%` <- function(x, y) if (is.null(x)) y else x


# ── Logging ───────────────────────────────────────────────────────────────────

#' Set the logging threshold for shokenuse
#'
#' @param level One of `"TRACE"`, `"DEBUG"`, `"INFO"` (default), `"WARN"`,
#'   `"ERROR"`, `"FATAL"`, or `"OFF"`.
#' @return `NULL` invisibly.
#' @export
util_log_threshold <- function(level = "INFO") {
  logger::log_threshold(level, namespace = "shokenuse")
  invisible(NULL)
}


# ── Reading ───────────────────────────────────────────────────────────────────

.metrics_cols <- c("date", "session", "project", "directory", "url",
                   "prompt", "tokens", "cost")

#' Default token-metrics directory
#'
#' The folder where `token-metrics.py` writes one CSV per day
#' (`YYYY-MM-DD-token-metrics.csv`).
#'
#' @return A path string.
#' @export
util_metrics_dir <- function() {
  "~/.cache/token-metrics"
}


#' Read token-metrics CSV files
#'
#' Reads the daily CSVs written by `token-metrics.py`, one row per prompt.
#' Each file must have the columns `date`, `session`, `project`,
#' `directory`, `url`, `prompt`, `tokens`, and `cost`.
#'
#' @param path A directory (every `*-token-metrics.csv` inside it is read) or
#'   a character vector of CSV file paths.
#' @return Tibble with `date` (POSIXct, local time), `day` (Date), `session`,
#'   `project`, `directory`, `url`, `prompt`, `tokens`, `cost`, sorted by
#'   `date` with duplicate rows removed.
#' @export
util_read_token_metrics <- function(path = util_metrics_dir()) {
  path <- fs::path_expand(path)

  files <- if (length(path) == 1 && fs::is_dir(path)) {
    fs::dir_ls(path, glob = "*-token-metrics.csv")
  } else {
    path
  }

  logger::log_info("Reading {length(files)} token-metrics file(s)",
                   namespace = "shokenuse")
  if (length(files) == 0) return(util_empty_metrics_tbl())

  raw <- dplyr::bind_rows(lapply(files, pvt_read_metrics_file))
  util_combine_metrics(pvt_tidy_metrics(raw))
}


pvt_read_metrics_file <- function(file) {
  df <- vroom::vroom(
    file, delim = ",",
    col_types = vroom::cols(.default = vroom::col_character()),
    show_col_types = FALSE, progress = FALSE
  )
  missing <- setdiff(.metrics_cols, names(df))
  if (length(missing) > 0) {
    rlang::abort(paste0(
      "Not a token-metrics file (", fs::path_file(file), "). Missing: ",
      paste(missing, collapse = ", ")
    ))
  }
  df[.metrics_cols]
}


pvt_tidy_metrics <- function(raw) {
  raw |>
    dplyr::mutate(
      day    = as.Date(substr(date, 1, 10)),
      date   = as.POSIXct(date, format = "%Y-%m-%dT%H:%M:%S"),
      url    = dplyr::na_if(url, ""),
      tokens = as.numeric(tokens),
      cost   = as.numeric(cost)
    ) |>
    dplyr::relocate(day, .after = date)
}


#' Combine token-metrics tibbles
#'
#' Row-binds tibbles from [util_read_token_metrics()], drops duplicate rows,
#' and sorts by `date`.
#'
#' @param ... Tibbles from [util_read_token_metrics()].
#' @return A single tibble.
#' @export
util_combine_metrics <- function(...) {
  dplyr::bind_rows(util_empty_metrics_tbl(), ...) |>
    dplyr::distinct() |>
    dplyr::arrange(date)
}


#' Empty token-metrics tibble
#'
#' @return Zero-row tibble with the columns of [util_read_token_metrics()].
#' @export
util_empty_metrics_tbl <- function() {
  tibble::tibble(
    date      = as.POSIXct(character()),
    day       = as.Date(character()),
    session   = character(),
    project   = character(),
    directory = character(),
    url       = character(),
    prompt    = character(),
    tokens    = numeric(),
    cost      = numeric()
  )
}


# ── Summaries ─────────────────────────────────────────────────────────────────

#' Summarise token metrics by grouping columns
#'
#' @param metrics Tibble from [util_read_token_metrics()].
#' @param by Character vector of grouping columns. Default `"day"`.
#' @return Tibble with the `by` columns plus `prompts`, `sessions`, `tokens`,
#'   and `cost`, sorted by descending `tokens`.
#' @export
util_summarise_metrics <- function(metrics, by = "day") {
  metrics |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
    dplyr::summarise(
      prompts  = dplyr::n(),
      sessions = dplyr::n_distinct(session),
      tokens   = sum(tokens, na.rm = TRUE),
      cost     = sum(cost,   na.rm = TRUE),
      .groups  = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(tokens))
}


#' Summarise token metrics by session
#'
#' One row per session. Outliers are sessions whose cost is more than two
#' standard deviations above the mean; none are flagged when the standard
#' deviation is zero or undefined.
#'
#' @param metrics Tibble from [util_read_token_metrics()].
#' @return Tibble with `session`, `project`, `start`, `minutes`, `prompts`,
#'   `tokens`, `cost`, `first_prompt`, and `outlier`, sorted by descending
#'   `cost`.
#' @export
util_summarise_sessions <- function(metrics) {
  if (nrow(metrics) == 0) {
    return(tibble::tibble(
      session = character(), project = character(),
      start = as.POSIXct(character()), minutes = numeric(),
      prompts = integer(), tokens = numeric(), cost = numeric(),
      first_prompt = character(), outlier = logical()
    ))
  }

  metrics |>
    dplyr::arrange(date) |>
    dplyr::group_by(session) |>
    dplyr::summarise(
      project      = paste(unique(project), collapse = ", "),
      start        = min(date),
      minutes      = as.numeric(difftime(max(date), min(date), units = "mins")),
      prompts      = dplyr::n(),
      tokens       = sum(tokens, na.rm = TRUE),
      cost         = sum(cost,   na.rm = TRUE),
      first_prompt = dplyr::first(prompt),
      .groups      = "drop"
    ) |>
    dplyr::mutate(outlier = pvt_flag_outliers(cost)) |>
    dplyr::arrange(dplyr::desc(cost))
}


pvt_flag_outliers <- function(x) {
  s <- stats::sd(x)
  if (is.na(s) || s == 0) return(rep(FALSE, length(x)))
  x > mean(x) + 2 * s
}


#' Keep the top projects and lump the rest
#'
#' @param metrics Tibble from [util_read_token_metrics()].
#' @param n Number of projects (by total tokens) to keep.
#' @return `metrics` with `project` values outside the top `n` replaced by
#'   `"other"`.
#' @export
util_lump_projects <- function(metrics, n = 8) {
  top <- util_summarise_metrics(metrics, by = "project") |>
    dplyr::slice_head(n = n) |>
    dplyr::pull(project)
  dplyr::mutate(metrics, project = ifelse(project %in% top, project, "other"))
}
