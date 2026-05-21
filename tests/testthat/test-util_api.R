library(shokenuse)

testthat::skip_if_not_installed("httr2")

# ── .fmt_datetime() ───────────────────────────────────────────────────────────

test_that(".fmt_datetime formats POSIXct to ISO-8601 UTC string", {
  ts <- as.POSIXct("2026-05-01 10:30:00", tz = "UTC")
  result <- shokenuse:::.fmt_datetime(ts)
  expect_equal(result, "2026-05-01T10:30:00Z")
})

test_that(".fmt_datetime accepts a character string", {
  result <- shokenuse:::.fmt_datetime("2026-01-15 00:00:00")
  expect_match(result, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
})


# ── Key validation ────────────────────────────────────────────────────────────

test_that("util_fetch_usage errors with an empty API key", {
  expect_error(
    util_fetch_usage(
      starting_at = "2026-05-01T00:00:00Z",
      api_key     = ""
    ),
    regexp = "Admin API key required"
  )
})

test_that("util_fetch_cost errors with an empty API key", {
  expect_error(
    util_fetch_cost(
      starting_at = "2026-05-01T00:00:00Z",
      api_key     = ""
    ),
    regexp = "Admin API key required"
  )
})

test_that("util_fetch_usage errors when ANTHROPIC_ADMIN_KEY is unset", {
  withr::with_envvar(c(ANTHROPIC_ADMIN_KEY = ""), {
    expect_error(
      util_fetch_usage("2026-05-01T00:00:00Z"),
      regexp = "Admin API key required"
    )
  })
})


# ── .parse_usage_response() ───────────────────────────────────────────────────

test_that(".parse_usage_response returns empty tibble for empty list", {
  result <- shokenuse:::.parse_usage_response(list())
  expect_equal(nrow(result), 0)
  expect_true("input_tokens" %in% names(result))
})

test_that(".parse_usage_response parses a minimal result list", {
  # Structure: list of pages -> each page has `data` -> each bucket has `results`
  sample <- list(
    list(
      data = list(
        list(
          starting_at = "2026-05-01T00:00:00Z",
          ending_at   = "2026-05-02T00:00:00Z",
          results     = list(
            list(
              uncached_input_tokens = 1000L,
              output_tokens         = 200L,
              cache_creation        = list(
                ephemeral_1h_input_tokens = 400L,
                ephemeral_5m_input_tokens = 100L
              ),
              cache_read_input_tokens = 300L,
              model                   = "claude-opus-4"
            )
          )
        )
      ),
      has_more  = FALSE,
      next_page = NULL
    )
  )
  result <- shokenuse:::.parse_usage_response(sample)
  expect_equal(nrow(result), 1)
  expect_equal(result$input_tokens, 1000L)
  expect_equal(result$cache_creation_input_tokens, 500L)
  expect_equal(result$model, "claude-opus-4")
})

test_that(".parse_usage_response drops all-NA optional columns", {
  sample <- list(
    list(
      data = list(
        list(
          starting_at = "2026-05-01T00:00:00Z",
          ending_at   = "2026-05-02T00:00:00Z",
          results     = list(
            list(
              uncached_input_tokens   = 100L,
              output_tokens           = 50L,
              cache_creation          = list(
                ephemeral_1h_input_tokens = 0L,
                ephemeral_5m_input_tokens = 0L
              ),
              cache_read_input_tokens = 0L
            )
          )
        )
      ),
      has_more  = FALSE,
      next_page = NULL
    )
  )
  result <- shokenuse:::.parse_usage_response(sample)
  expect_false("model" %in% names(result))
})


# ── .parse_cost_response() ────────────────────────────────────────────────────

test_that(".parse_cost_response returns empty tibble for empty list", {
  result <- shokenuse:::.parse_cost_response(list())
  expect_equal(nrow(result), 0)
  expect_true("cost_usd" %in% names(result))
})

test_that(".parse_cost_response parses a cost result", {
  sample <- list(
    list(
      data = list(
        list(
          starting_at = "2026-05-01T00:00:00Z",
          ending_at   = "2026-05-02T00:00:00Z",
          results     = list(
            list(cost = 12.50, workspace_id = "ws_abc")
          )
        )
      ),
      has_more  = FALSE,
      next_page = NULL
    )
  )
  result <- shokenuse:::.parse_cost_response(sample)
  expect_equal(nrow(result), 1)
  expect_equal(result$cost_usd, 12.50)
  expect_equal(result$workspace_id, "ws_abc")
})
