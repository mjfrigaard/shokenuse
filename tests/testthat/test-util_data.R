library(shokenuse)

# ── Helpers ───────────────────────────────────────────────────────────────────

make_rows <- function(
    session_id,
    timestamps = as.POSIXct("2026-05-01 10:00:00", tz = "UTC"),
    model      = "claude-opus-4",
    input      = 100L,
    output     = 50L,
    cache_cre  = 0L,
    cache_read = 0L,
    machine    = "test-mac",
    source     = "claude_code",
    project    = "projects/test",
    cost_usd   = NULL) {

  n   <- length(timestamps)
  row <- tibble::tibble(
    timestamp             = timestamps,
    machine               = machine,
    source                = source,
    project               = project,
    session_id            = session_id,
    model                 = model,
    input_tokens          = as.integer(rep_len(input,      n)),
    cache_creation_tokens = as.integer(rep_len(cache_cre,  n)),
    cache_read_tokens     = as.integer(rep_len(cache_read, n)),
    output_tokens         = as.integer(rep_len(output,     n))
  )
  if (!is.null(cost_usd)) row$cost_usd <- rep_len(cost_usd, n)
  row
}

make_sessions <- function(costs) {
  dplyr::bind_rows(
    mapply(
      \(sid, cost) make_rows(session_id = sid, cost_usd = cost),
      names(costs), costs,
      SIMPLIFY = FALSE
    )
  )
}

make_csv <- function(path, extra_cols = list()) {
  df <- data.frame(
    timestamp    = "2026-05-01 10:00:00",
    source       = "console",
    model        = "claude-opus-4",
    input_tokens  = 100L,
    output_tokens = 50L
  )
  for (nm in names(extra_cols)) df[[nm]] <- extra_cols[[nm]]
  utils::write.csv(df, path, row.names = FALSE)
  path
}


# ── util_model_pricing() ──────────────────────────────────────────────────────

test_that("util_model_pricing returns tibble with correct columns", {
  p <- util_model_pricing()
  expect_s3_class(p, "tbl_df")
  expect_named(p, c("model", "input_pm", "output_pm", "cache_write_pm", "cache_read_pm"))
})

test_that("util_model_pricing contains 'unknown' fallback row", {
  p <- util_model_pricing()
  expect_true("unknown" %in% p$model)
})

test_that("util_model_pricing prices are positive", {
  p <- util_model_pricing()
  numeric_cols <- c("input_pm", "output_pm", "cache_write_pm", "cache_read_pm")
  expect_true(all(vapply(numeric_cols, function(col) all(p[[col]] > 0), logical(1))))
})


# ── util_add_cost() ───────────────────────────────────────────────────────────

test_that("util_add_cost appends cost_usd column", {
  usage  <- make_rows("s1")
  result <- util_add_cost(usage)
  expect_true("cost_usd" %in% names(result))
})

test_that("util_add_cost computes correct cost for claude-opus-4", {
  # 1 M input tokens at $15/M = $15
  usage <- tibble::tibble(
    timestamp             = as.POSIXct("2026-05-01", tz = "UTC"),
    machine = "m", source = "s", project = "p", session_id = "x",
    model                 = "claude-opus-4",
    input_tokens          = 1000000L,
    output_tokens         = 0L,
    cache_creation_tokens = 0L,
    cache_read_tokens     = 0L
  )
  result <- util_add_cost(usage)
  expect_equal(result$cost_usd, 15.0)
})

test_that("util_add_cost uses fallback prices for unknown model", {
  usage <- make_rows("s1", model = "claude-future-99")
  result <- util_add_cost(usage)
  expect_true("cost_usd" %in% names(result))
  expect_gt(result$cost_usd, 0)
})

test_that("util_add_cost does not leave pricing join columns", {
  result <- util_add_cost(make_rows("s1"))
  expect_false(any(c("input_pm", "output_pm") %in% names(result)))
})


# ── util_empty_usage_tbl() ────────────────────────────────────────────────────

test_that("util_empty_usage_tbl has zero rows and correct columns", {
  tbl <- util_empty_usage_tbl()
  expect_equal(nrow(tbl), 0)
  expect_named(tbl, c(
    "timestamp", "machine", "source", "project", "session_id", "model",
    "input_tokens", "cache_creation_tokens", "cache_read_tokens", "output_tokens"
  ))
})

test_that("util_empty_usage_tbl column types are correct", {
  tbl <- util_empty_usage_tbl()
  expect_s3_class(tbl$timestamp, "POSIXct")
  expect_type(tbl$machine,      "character")
  expect_type(tbl$input_tokens, "integer")
})


# ── util_summarise_usage() ────────────────────────────────────────────────────

test_that("util_summarise_usage groups by date by default", {
  usage <- dplyr::bind_rows(
    make_rows("s1", timestamps = as.POSIXct("2026-05-01 10:00", tz = "UTC"),
              input = 100L, output = 50L, cost_usd = 0.01),
    make_rows("s2", timestamps = as.POSIXct("2026-05-01 12:00", tz = "UTC"),
              input = 200L, output = 100L, cost_usd = 0.02),
    make_rows("s3", timestamps = as.POSIXct("2026-05-02 09:00", tz = "UTC"),
              input = 50L, output = 25L, cost_usd = 0.005)
  )
  usage <- dplyr::mutate(usage, date = as.Date(timestamp))
  result <- util_summarise_usage(usage)
  expect_equal(nrow(result), 2)
})

test_that("util_summarise_usage total_tokens = sum of all four types", {
  usage <- make_rows("s1", input = 10L, output = 20L,
                     cache_cre = 30L, cache_read = 40L, cost_usd = 0)
  usage <- dplyr::mutate(usage, date = as.Date(timestamp))
  result <- util_summarise_usage(usage)
  expect_equal(result$total_tokens, 100L)
})

test_that("util_summarise_usage groups by model", {
  usage <- dplyr::bind_rows(
    make_rows("s1", model = "claude-opus-4",   cost_usd = 1),
    make_rows("s2", model = "claude-sonnet-4", cost_usd = 0.1)
  )
  result <- util_summarise_usage(util_add_cost(usage), by = "model")
  expect_equal(nrow(result), 2)
  expect_true("model" %in% names(result))
})


# ── util_combine_usage() ─────────────────────────────────────────────────────

test_that("util_combine_usage sorts by timestamp", {
  a <- make_rows("s1", timestamps = as.POSIXct("2026-05-02", tz = "UTC"))
  b <- make_rows("s2", timestamps = as.POSIXct("2026-05-01", tz = "UTC"))
  result <- util_combine_usage(a, b)
  expect_equal(result$session_id, c("s2", "s1"))
})

test_that("util_combine_usage binds rows from multiple frames", {
  a <- make_rows("s1")
  b <- make_rows("s2")
  result <- util_combine_usage(a, b)
  expect_equal(nrow(result), 2)
})


# ── util_read_usage_csv() ─────────────────────────────────────────────────────

test_that("util_read_usage_csv reads required columns", {
  path   <- tempfile(fileext = ".csv")
  make_csv(path)
  result <- util_read_usage_csv(path)
  expect_named(result, c(
    "timestamp", "machine", "source", "project", "session_id",
    "model", "input_tokens", "cache_creation_tokens",
    "cache_read_tokens", "output_tokens"
  ))
  unlink(path)
})

test_that("util_read_usage_csv errors on missing required columns", {
  path <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(col_a = 1, col_b = "foo"), path, row.names = FALSE)
  expect_error(util_read_usage_csv(path), "missing required columns")
  unlink(path)
})

test_that("util_read_usage_csv fills optional cache columns with 0", {
  path   <- tempfile(fileext = ".csv")
  make_csv(path)
  result <- util_read_usage_csv(path)
  expect_equal(result$cache_creation_tokens, 0L)
  expect_equal(result$cache_read_tokens,     0L)
  unlink(path)
})

test_that("util_read_usage_csv uses machine arg as default machine", {
  path   <- tempfile(fileext = ".csv")
  make_csv(path)
  result <- util_read_usage_csv(path, machine = "test-box")
  expect_equal(result$machine, "test-box")
  unlink(path)
})


# ── util_summarise_sessions() ─────────────────────────────────────────────────

test_that("empty input returns zero-row tibble with correct columns", {
  result <- util_summarise_sessions(util_empty_usage_tbl())
  expect_equal(nrow(result), 0)
  expect_named(result, c(
    "session_id", "project", "machine", "source",
    "date", "duration_min", "models", "n_requests",
    "input_tokens", "output_tokens",
    "cache_creation_tokens", "cache_read_tokens",
    "total_tokens", "cost_usd", "outlier"
  ))
})

test_that("output columns have correct types", {
  result <- util_summarise_sessions(make_rows("s1"))
  expect_s3_class(result$date,         "Date")
  expect_type(result$duration_min,     "double")
  expect_type(result$models,           "character")
  expect_type(result$n_requests,       "integer")
  expect_type(result$input_tokens,     "integer")
  expect_type(result$output_tokens,    "integer")
  expect_type(result$total_tokens,     "integer")
  expect_type(result$cost_usd,         "double")
  expect_type(result$outlier,          "logical")
})

test_that("single session produces one row", {
  result <- util_summarise_sessions(make_rows("s1"))
  expect_equal(nrow(result), 1)
  expect_equal(result$session_id, "s1")
})

test_that("single session is never flagged as outlier", {
  result <- util_summarise_sessions(make_rows("s1", cost_usd = 99))
  expect_false(result$outlier)
})

test_that("single session has zero duration", {
  result <- util_summarise_sessions(make_rows("s1"))
  expect_equal(result$duration_min, 0)
})

test_that("token counts sum across requests within a session", {
  usage <- make_rows(
    "s1",
    timestamps = as.POSIXct(c("2026-05-01 10:00:00",
                               "2026-05-01 10:05:00"), tz = "UTC"),
    input      = 100L,
    output     = 50L,
    cache_cre  = 200L,
    cache_read = 300L,
    cost_usd   = 0.01
  )
  result <- util_summarise_sessions(usage)
  expect_equal(result$input_tokens,          200L)
  expect_equal(result$output_tokens,         100L)
  expect_equal(result$cache_creation_tokens, 400L)
  expect_equal(result$cache_read_tokens,     600L)
  expect_equal(result$total_tokens,          1300L)
  expect_equal(result$cost_usd,              0.02)
})

test_that("total_tokens equals sum of all four token types", {
  usage  <- make_rows("s1", input = 10L, output = 20L,
                      cache_cre = 30L, cache_read = 40L, cost_usd = 0)
  result <- util_summarise_sessions(usage)
  expect_equal(result$total_tokens, 100L)
})

test_that("duration_min is time between first and last request", {
  usage <- make_rows(
    "s1",
    timestamps = as.POSIXct(c("2026-05-01 09:00:00",
                               "2026-05-01 09:30:00",
                               "2026-05-01 10:00:00"), tz = "UTC"),
    cost_usd = 0.01
  )
  result <- util_summarise_sessions(usage)
  expect_equal(result$duration_min, 60)
})

test_that("n_requests equals number of rows for the session", {
  usage <- make_rows(
    "s1",
    timestamps = as.POSIXct(c("2026-05-01 10:00:00",
                               "2026-05-01 10:01:00",
                               "2026-05-01 10:02:00"), tz = "UTC"),
    cost_usd = 0.01
  )
  result <- util_summarise_sessions(usage)
  expect_equal(result$n_requests, 3L)
})

test_that("multiple models in a session are sorted and comma-joined", {
  usage <- dplyr::bind_rows(
    make_rows("s1", model = "claude-sonnet-4",  cost_usd = 0.01),
    make_rows("s1", model = "claude-haiku-3-5", cost_usd = 0.01),
    make_rows("s1", model = "claude-opus-4",    cost_usd = 0.01)
  )
  result <- util_summarise_sessions(usage)
  expect_equal(result$models, "claude-haiku-3-5, claude-opus-4, claude-sonnet-4")
})

test_that("duplicate models within a session are deduplicated", {
  usage <- dplyr::bind_rows(
    make_rows("s1", model = "claude-opus-4", cost_usd = 0.01),
    make_rows("s1", model = "claude-opus-4", cost_usd = 0.01)
  )
  result <- util_summarise_sessions(usage)
  expect_equal(result$models, "claude-opus-4")
})

test_that("rows are ordered by descending cost_usd", {
  usage  <- make_sessions(list(cheap = 0.01, expensive = 5.00, mid = 0.50))
  result <- util_summarise_sessions(usage)
  expect_equal(result$session_id, c("expensive", "mid", "cheap"))
})

test_that("each session_id produces exactly one row", {
  usage <- dplyr::bind_rows(
    make_rows("s1", cost_usd = 0.01),
    make_rows("s1", cost_usd = 0.01),
    make_rows("s2", cost_usd = 0.02),
    make_rows("s3", cost_usd = 0.03)
  )
  result <- util_summarise_sessions(usage)
  expect_equal(nrow(result), 3)
  expect_setequal(result$session_id, c("s1", "s2", "s3"))
})

test_that("session more than 2 SD above mean is flagged as outlier", {
  costs <- c(setNames(rep(0.01, 9), paste0("cheap-", seq_len(9))),
             list(pricey = 10.00))
  result <- util_summarise_sessions(make_sessions(costs))
  expect_true(result$outlier[result$session_id == "pricey"])
  expect_true(all(!result$outlier[result$session_id != "pricey"]))
})

test_that("no sessions flagged when all costs are identical (SD = 0)", {
  costs  <- setNames(rep(0.05, 5), paste0("s", seq_len(5)))
  result <- util_summarise_sessions(make_sessions(costs))
  expect_equal(sum(result$outlier), 0L)
})

test_that("no sessions flagged when only two sessions exist", {
  usage  <- make_sessions(list(s1 = 0.01, s2 = 0.02))
  result <- util_summarise_sessions(usage)
  expect_equal(sum(result$outlier), 0L)
})

test_that("cost_usd is computed automatically when absent from input", {
  usage <- make_rows("s1")
  expect_false("cost_usd" %in% names(usage))
  result <- util_summarise_sessions(usage)
  expect_true("cost_usd" %in% names(result))
  expect_gt(result$cost_usd, 0)
})

test_that("date column is the calendar date of the earliest request", {
  usage <- make_rows(
    "s1",
    timestamps = as.POSIXct(c("2026-04-10 23:55:00",
                               "2026-04-11 00:05:00"), tz = "UTC"),
    cost_usd = 0.01
  )
  result <- util_summarise_sessions(usage)
  expect_equal(result$date, as.Date("2026-04-10"))
})
