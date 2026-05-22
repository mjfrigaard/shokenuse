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


# ── util_label_api_source() ───────────────────────────────────────────────────

.mock_api_keys_response <- function(rows) {
  body <- jsonlite::toJSON(
    list(data = rows, has_more = FALSE),
    auto_unbox = TRUE
  )
  httr2::response(
    status_code = 200,
    headers     = list("content-type" = "application/json"),
    body        = charToRaw(body)
  )
}

test_that("util_label_api_source returns input unchanged when api_key_id is missing", {
  usage  <- tibble::tibble(input_tokens = 100L)
  result <- util_label_api_source(usage, api_key = "test_key")
  expect_identical(result, usage)
})

test_that("util_label_api_source errors with an empty API key", {
  usage <- tibble::tibble(api_key_id = "apikey_001", input_tokens = 100L)
  expect_error(
    util_label_api_source(usage, api_key = ""),
    regexp = "Admin API key required"
  )
})

test_that("util_label_api_source applies maintainer-default labels and falls back for unknown keys", {
  testthat::skip_if_not_installed("httptest2")

  usage <- tibble::tibble(
    timestamp_bucket = "2026-05-01T00:00:00Z",
    api_key_id       = c("apikey_001", "apikey_002", "apikey_003", "apikey_unknown"),
    input_tokens     = c(100L, 200L, 300L, 50L),
    output_tokens    = c(10L, 20L, 30L, 5L)
  )

  mock <- function(req) {
    .mock_api_keys_response(list(
      list(id = "apikey_001", name = "sys76-positron-key"),
      list(id = "apikey_002", name = "claude_code_key_mjfrigaard_apaw"),
      list(id = "apikey_003", name = "some-other-key")
    ))
  }

  result <- httptest2::with_mocked_responses(
    mock,
    util_label_api_source(usage, api_key = "test_key")
  )

  expect_equal(
    result$source,
    c("positron (System76)", "positron (macOS)", "some-other-key", "anthropic_api")
  )
  expect_equal(
    result$api_key_name,
    c("sys76-positron-key", "claude_code_key_mjfrigaard_apaw",
      "some-other-key", NA_character_)
  )
  expect_equal(result$input_tokens, c(100L, 200L, 300L, 50L))
})

test_that("util_label_api_source honours a custom labels argument", {
  testthat::skip_if_not_installed("httptest2")

  usage <- tibble::tibble(api_key_id = "apikey_001", input_tokens = 100L)

  mock <- function(req) {
    .mock_api_keys_response(list(
      list(id = "apikey_001", name = "my-personal-key")
    ))
  }

  result <- httptest2::with_mocked_responses(
    mock,
    util_label_api_source(
      usage,
      labels  = c("my-personal-key" = "scripts"),
      api_key = "test_key"
    )
  )

  expect_equal(result$source, "scripts")
  expect_equal(result$api_key_name, "my-personal-key")
})

test_that(".fetch_api_keys returns an empty tibble when the org has no keys", {
  testthat::skip_if_not_installed("httptest2")

  mock <- function(req) .mock_api_keys_response(list())

  result <- httptest2::with_mocked_responses(
    mock,
    shokenuse:::.fetch_api_keys("test_key")
  )

  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("api_key_id", "api_key_name"))
})
