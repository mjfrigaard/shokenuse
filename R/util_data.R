# ── Null-coalesce operator ─────────────────────────────────────────────────────

`%||%` <- function(x, y) if (is.null(x)) y else x


# ── Logging ───────────────────────────────────────────────────────────────────

#' Set the logging threshold for shokenuse
#'
#' Controls the verbosity of shokenuse log output. Use `"DEBUG"` to see
#' per-file and per-request detail; `"INFO"` for normal operation; `"OFF"` to
#' silence all output.
#'
#' @param level One of `"TRACE"`, `"DEBUG"`, `"INFO"` (default), `"WARN"`,
#'   `"ERROR"`, `"FATAL"`, or `"OFF"`.
#' @return `NULL` invisibly.
#' @export
util_log_threshold <- function(level = "INFO") {
  logger::log_threshold(level, namespace = "shokenuse")
  invisible(NULL)
}


# ── Pricing ───────────────────────────────────────────────────────────────────

#' Anthropic model pricing (USD per million tokens)
#'
#' Returns per-million-token prices for input, output, cache creation, and
#' cache read for known Claude models. Update when Anthropic changes pricing.
#'
#' @return Tibble with columns `model`, `input_pm`, `output_pm`,
#'   `cache_write_pm`, `cache_read_pm`.
#' @export
util_model_pricing <- function() {
  tibble::tribble(
    ~model,               ~input_pm, ~output_pm, ~cache_write_pm, ~cache_read_pm,
    "claude-opus-4",          15.00,      75.00,           18.75,           1.50,
    "claude-sonnet-4",         3.00,      15.00,            3.75,           0.30,
    "claude-opus-3-5",        15.00,      75.00,           18.75,           1.50,
    "claude-sonnet-3-7",       3.00,      15.00,            3.75,           0.30,
    "claude-sonnet-3-5",       3.00,      15.00,            3.75,           0.30,
    "claude-sonnet-3",         3.00,      15.00,            3.75,           0.30,
    "claude-haiku-3-5",        0.80,       4.00,            1.00,           0.08,
    "claude-haiku-3",          0.25,       1.25,            0.30,           0.03,
    "unknown",                 3.00,      15.00,            3.75,           0.30
  )
}


#' Add estimated cost column to a usage tibble
#'
#' Joins each row's model to [util_model_pricing()] and appends a `cost_usd`
#' column. Models not found in the table fall back to `"unknown"` prices.
#'
#' @param usage Tibble from [util_read_claude_code()] or [util_combine_usage()].
#' @return Input tibble with `cost_usd` appended.
#' @export
util_add_cost <- function(usage) {
  logger::log_debug("Adding cost to {nrow(usage)} rows", namespace = "shokenuse")

  pricing      <- util_model_pricing()
  known_models <- pricing$model[pricing$model != "unknown"]
  unknown      <- unique(usage$model[!usage$model %in% known_models])

  if (length(unknown) > 0) {
    logger::log_warn(
      "Unknown models using fallback pricing: {paste(unknown, collapse = ', ')}",
      namespace = "shokenuse"
    )
  }

  result <- tryCatch(
    {
      usage |>
        dplyr::left_join(pricing, by = "model") |>
        dplyr::mutate(
          input_pm       = dplyr::coalesce(input_pm,
                             pricing$input_pm[pricing$model == "unknown"]),
          output_pm      = dplyr::coalesce(output_pm,
                             pricing$output_pm[pricing$model == "unknown"]),
          cache_write_pm = dplyr::coalesce(cache_write_pm,
                             pricing$cache_write_pm[pricing$model == "unknown"]),
          cache_read_pm  = dplyr::coalesce(cache_read_pm,
                             pricing$cache_read_pm[pricing$model == "unknown"]),
          cost_usd = (input_tokens          / 1e6) * input_pm  +
                     (output_tokens         / 1e6) * output_pm +
                     (cache_creation_tokens / 1e6) * cache_write_pm +
                     (cache_read_tokens     / 1e6) * cache_read_pm
        ) |>
        dplyr::select(-input_pm, -output_pm, -cache_write_pm, -cache_read_pm)
    },
    error = function(e) {
      logger::log_error(
        "util_add_cost failed: {conditionMessage(e)}",
        namespace = "shokenuse"
      )
      rlang::abort(paste("util_add_cost failed:", conditionMessage(e)), parent = e)
    }
  )

  logger::log_debug(
    "Cost computed — total: ${round(sum(result$cost_usd, na.rm = TRUE), 4)}",
    namespace = "shokenuse"
  )
  result
}


#' Summarise usage by grouping variables
#'
#' @param usage Tibble from [util_read_claude_code()] or [util_combine_usage()].
#' @param by Character vector of grouping column names. Default `"date"`.
#' @return Summarised tibble with token totals, cost, `n_requests`, and
#'   `total_tokens`.
#' @export
util_summarise_usage <- function(usage, by = "date") {
  logger::log_debug(
    "Summarising {nrow(usage)} rows by: {paste(by, collapse = ', ')}",
    namespace = "shokenuse"
  )

  if (!"date" %in% names(usage) && "timestamp" %in% names(usage)) {
    usage <- dplyr::mutate(usage, date = as.Date(timestamp))
  }
  if (!"cost_usd" %in% names(usage)) {
    usage <- util_add_cost(usage)
  }

  result <- usage |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
    dplyr::summarise(
      input_tokens          = sum(input_tokens,          na.rm = TRUE),
      cache_creation_tokens = sum(cache_creation_tokens, na.rm = TRUE),
      cache_read_tokens     = sum(cache_read_tokens,     na.rm = TRUE),
      output_tokens         = sum(output_tokens,         na.rm = TRUE),
      cost_usd              = sum(cost_usd,              na.rm = TRUE),
      n_requests            = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      total_tokens = input_tokens + cache_creation_tokens +
                     cache_read_tokens + output_tokens
    )

  logger::log_debug(
    "Summarise result: {nrow(result)} group(s)",
    namespace = "shokenuse"
  )
  result
}


# ── JSONL reading ──────────────────────────────────────────────────────────────

#' Read token usage from Claude Code JSONL files
#'
#' Scans all JSONL files under `claude_dir` recursively and extracts token
#' usage from assistant messages. Each row is one API response.
#'
#' @param claude_dir Path to the Claude projects directory.
#'   Defaults to `~/.claude/projects`.
#' @param machine Label stored in the `machine` column, e.g. `"macOS"`.
#' @return Tibble with columns `timestamp`, `machine`, `source`, `project`,
#'   `session_id`, `model`, `input_tokens`, `cache_creation_tokens`,
#'   `cache_read_tokens`, `output_tokens`.
#' @export
util_read_claude_code <- function(
    claude_dir = fs::path_home(".claude", "projects"),
    machine = "local") {

  claude_dir <- fs::path_expand(claude_dir)
  logger::log_info(
    "Scanning {claude_dir} [machine={machine}]",
    namespace = "shokenuse"
  )

  if (!fs::dir_exists(claude_dir)) {
    logger::log_warn(
      "Directory not found: {claude_dir}",
      namespace = "shokenuse"
    )
    return(util_empty_usage_tbl())
  }

  jsonl_files <- fs::dir_ls(claude_dir, recurse = TRUE, glob = "*.jsonl")
  logger::log_info(
    "Found {length(jsonl_files)} JSONL file(s) in {claude_dir}",
    namespace = "shokenuse"
  )

  if (length(jsonl_files) == 0) return(util_empty_usage_tbl())

  result <- tryCatch(
    dplyr::bind_rows(lapply(jsonl_files, .parse_claude_jsonl, machine = machine)),
    error = function(e) {
      logger::log_error(
        "Failed to parse JSONL files from {claude_dir}: {conditionMessage(e)}",
        namespace = "shokenuse"
      )
      util_empty_usage_tbl()
    }
  )

  logger::log_info(
    "Read {nrow(result)} usage row(s) from {machine}",
    namespace = "shokenuse"
  )
  result
}


.parse_claude_jsonl <- function(path, machine) {
  logger::log_debug("Parsing {path}", namespace = "shokenuse")

  lines <- tryCatch(
    readLines(path, warn = FALSE),
    error = function(e) {
      logger::log_warn(
        "Cannot read {path}: {conditionMessage(e)}",
        namespace = "shokenuse"
      )
      character(0)
    }
  )

  if (length(lines) == 0) return(util_empty_usage_tbl())

  project    <- fs::path_file(fs::path_dir(path))
  project    <- sub("^-Users-[^-]+-", "", project)
  project    <- gsub("-", "/", project)
  session_id <- fs::path_ext_remove(fs::path_file(path))

  rows <- lapply(lines, function(line) {
    tryCatch(
      .extract_usage_row(line, machine, project, session_id),
      error = function(e) {
        logger::log_debug(
          "Skipping malformed line in {session_id}: {conditionMessage(e)}",
          namespace = "shokenuse"
        )
        NULL
      }
    )
  })

  result <- dplyr::bind_rows(Filter(Negate(is.null), rows))
  logger::log_debug(
    "Extracted {nrow(result)} row(s) from session {session_id}",
    namespace = "shokenuse"
  )
  result
}


.extract_usage_row <- function(line, machine, project, session_id) {
  if (!nzchar(trimws(line))) return(NULL)
  msg <- jsonlite::fromJSON(line, simplifyVector = FALSE)
  if (!identical(msg[["type"]], "assistant")) return(NULL)

  usage <- msg[["message"]][["usage"]]
  if (is.null(usage)) return(NULL)

  model <- msg[["message"]][["model"]]
  if (is.null(model) || !nzchar(model)) return(NULL)

  ts_raw <- msg[["timestamp"]]
  ts <- if (!is.null(ts_raw)) {
    lubridate::ymd_hms(ts_raw, quiet = TRUE)
  } else {
    lubridate::NA_POSIXct_
  }

  tibble::tibble(
    timestamp             = ts,
    machine               = machine,
    source                = "claude_code",
    project               = project,
    session_id            = session_id,
    model                 = .normalise_model(model),
    input_tokens          = as.integer(usage[["input_tokens"]]                %||% 0L),
    cache_creation_tokens = as.integer(usage[["cache_creation_input_tokens"]] %||% 0L),
    cache_read_tokens     = as.integer(usage[["cache_read_input_tokens"]]     %||% 0L),
    output_tokens         = as.integer(usage[["output_tokens"]]               %||% 0L)
  )
}


.normalise_model <- function(x) {
  x <- tolower(trimws(x))
  dplyr::case_when(
    grepl("opus-4",     x) ~ "claude-opus-4",
    grepl("opus-3-5",   x) ~ "claude-opus-3-5",
    grepl("opus-3",     x) ~ "claude-opus-3",
    grepl("sonnet-4",   x) ~ "claude-sonnet-4",
    grepl("sonnet-3-7", x) ~ "claude-sonnet-3-7",
    grepl("sonnet-3-5", x) ~ "claude-sonnet-3-5",
    grepl("sonnet-3",   x) ~ "claude-sonnet-3",
    grepl("haiku-3-5",  x) ~ "claude-haiku-3-5",
    grepl("haiku-3",    x) ~ "claude-haiku-3",
    TRUE                   ~ x
  )
}


#' Read a manually exported usage CSV
#'
#' Required columns: `timestamp`, `source`, `model`, `input_tokens`,
#' `output_tokens`. Optional: `machine`, `project`, `session_id`,
#' `cache_creation_tokens`, `cache_read_tokens`.
#'
#' @param path Path to CSV file.
#' @param machine Machine label used when no `machine` column is present.
#' @return Tibble matching the schema of [util_read_claude_code()].
#' @export
util_read_usage_csv <- function(path, machine = "manual") {
  logger::log_info(
    "Reading CSV: {path} [machine={machine}]",
    namespace = "shokenuse"
  )

  df <- tryCatch(
    vroom::vroom(path, delim = ",", show_col_types = FALSE, progress = FALSE),
    error = function(e) {
      logger::log_error(
        "Failed to read CSV {path}: {conditionMessage(e)}",
        namespace = "shokenuse"
      )
      rlang::abort(paste("Cannot read CSV:", conditionMessage(e)), parent = e)
    }
  )

  logger::log_debug(
    "CSV loaded: {nrow(df)} row(s), {ncol(df)} column(s)",
    namespace = "shokenuse"
  )

  required <- c("timestamp", "source", "model", "input_tokens", "output_tokens")
  missing  <- setdiff(required, names(df))
  if (length(missing) > 0) {
    logger::log_error(
      "CSV missing required columns: {paste(missing, collapse = ', ')}",
      namespace = "shokenuse"
    )
    rlang::abort(paste("CSV missing required columns:", paste(missing, collapse = ", ")))
  }

  if (!"machine"               %in% names(df)) df$machine               <- machine
  if (!"project"               %in% names(df)) df$project               <- NA_character_
  if (!"session_id"            %in% names(df)) df$session_id            <- NA_character_
  if (!"cache_creation_tokens" %in% names(df)) df$cache_creation_tokens <- 0L
  if (!"cache_read_tokens"     %in% names(df)) df$cache_read_tokens     <- 0L

  result <- df |>
    dplyr::mutate(
      timestamp             = lubridate::as_datetime(timestamp),
      model                 = .normalise_model(as.character(model)),
      input_tokens          = as.integer(input_tokens),
      output_tokens         = as.integer(output_tokens),
      cache_creation_tokens = as.integer(cache_creation_tokens),
      cache_read_tokens     = as.integer(cache_read_tokens)
    ) |>
    dplyr::select(timestamp, machine, source, project, session_id,
                  model, input_tokens, cache_creation_tokens,
                  cache_read_tokens, output_tokens)

  logger::log_info(
    "CSV parsed: {nrow(result)} row(s) ready",
    namespace = "shokenuse"
  )
  result
}


#' Combine usage data frames from multiple sources
#'
#' Row-binds any number of data frames from [util_read_claude_code()] or
#' [util_read_usage_csv()] and sorts by timestamp.
#'
#' @param ... Data frames to combine.
#' @return Single tibble sorted by timestamp.
#' @export
util_combine_usage <- function(...) {
  frames   <- list(...)
  n_frames <- length(frames)
  n_in     <- sum(vapply(frames, nrow, integer(1)))
  logger::log_debug(
    "Combining {n_frames} frame(s) ({n_in} row(s) total)",
    namespace = "shokenuse"
  )

  result <- dplyr::bind_rows(...) |> dplyr::arrange(timestamp)

  logger::log_debug(
    "Combined result: {nrow(result)} row(s)",
    namespace = "shokenuse"
  )
  result
}


#' Return an empty usage tibble with the canonical schema
#'
#' @return Zero-row tibble with correct column types.
#' @export
util_empty_usage_tbl <- function() {
  tibble::tibble(
    timestamp             = lubridate::POSIXct(0)[-1],
    machine               = character(),
    source                = character(),
    project               = character(),
    session_id            = character(),
    model                 = character(),
    input_tokens          = integer(),
    cache_creation_tokens = integer(),
    cache_read_tokens     = integer(),
    output_tokens         = integer()
  )
}


# ── Sessions ──────────────────────────────────────────────────────────────────

#' Summarise token usage by session
#'
#' Aggregates to one row per session (`session_id`). Outliers are sessions
#' whose cost exceeds mean + 2 SD. When SD is zero or undefined no session
#' is flagged.
#'
#' @param usage Tibble from [util_read_claude_code()] or [util_combine_usage()].
#'   Cost is computed automatically if `cost_usd` is absent.
#' @return One-row-per-session tibble with `session_id`, `project`, `machine`,
#'   `source`, `date`, `duration_min`, `models`, `n_requests`, token columns,
#'   `total_tokens`, `cost_usd`, `outlier`. Ordered by descending `cost_usd`.
#' @export
util_summarise_sessions <- function(usage) {
  logger::log_info(
    "Summarising {nrow(usage)} row(s) into sessions",
    namespace = "shokenuse"
  )

  if (nrow(usage) == 0) return(.empty_session_tbl())
  if (!"cost_usd" %in% names(usage)) usage <- util_add_cost(usage)

  result <- usage |>
    dplyr::group_by(session_id, project, machine, source) |>
    dplyr::summarise(
      date                  = as.Date(min(timestamp, na.rm = TRUE)),
      duration_min          = as.numeric(difftime(
        max(timestamp, na.rm = TRUE),
        min(timestamp, na.rm = TRUE),
        units = "mins"
      )),
      models                = paste(sort(unique(model)), collapse = ", "),
      n_requests            = dplyr::n(),
      input_tokens          = sum(input_tokens,          na.rm = TRUE),
      output_tokens         = sum(output_tokens,         na.rm = TRUE),
      cache_creation_tokens = sum(cache_creation_tokens, na.rm = TRUE),
      cache_read_tokens     = sum(cache_read_tokens,     na.rm = TRUE),
      cost_usd              = sum(cost_usd,              na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      total_tokens = input_tokens + output_tokens +
                     cache_creation_tokens + cache_read_tokens,
      outlier = {
        sd_val <- stats::sd(cost_usd)
        if (is.na(sd_val) || sd_val == 0) rep(FALSE, dplyr::n())
        else cost_usd > (mean(cost_usd) + 2 * sd_val)
      }
    ) |>
    dplyr::arrange(dplyr::desc(cost_usd))

  logger::log_info(
    "Sessions: {nrow(result)} total, {sum(result$outlier)} outlier(s)",
    namespace = "shokenuse"
  )
  result
}


.empty_session_tbl <- function() {
  tibble::tibble(
    session_id            = character(),
    project               = character(),
    machine               = character(),
    source                = character(),
    date                  = as.Date(character()),
    duration_min          = numeric(),
    models                = character(),
    n_requests            = integer(),
    input_tokens          = integer(),
    output_tokens         = integer(),
    cache_creation_tokens = integer(),
    cache_read_tokens     = integer(),
    total_tokens          = integer(),
    cost_usd              = numeric(),
    outlier               = logical()
  )
}


# ── Plot helper ───────────────────────────────────────────────────────────────

.empty_plot <- function(msg = "No data available") {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg,
                      size = 5, color = "grey50") +
    ggplot2::theme_void()
}
