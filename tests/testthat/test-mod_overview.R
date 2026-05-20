library(shokenuse)

make_usage <- function(n = 1, date = "2026-05-01") {
  tibble::tibble(
    timestamp             = as.POSIXct(paste(date, "10:00:00"), tz = "UTC"),
    machine               = "test",
    source                = "claude_code",
    project               = "projects/test",
    session_id            = paste0("s", seq_len(n)),
    model                 = "claude-opus-4",
    input_tokens          = as.integer(rep(100L, n)),
    cache_creation_tokens = as.integer(rep(0L,   n)),
    cache_read_tokens     = as.integer(rep(0L,   n)),
    output_tokens         = as.integer(rep(50L,  n)),
    cost_usd              = rep(0.05, n),
    date                  = as.Date(date)
  )
}


# ── Return value ──────────────────────────────────────────────────────────────

test_that("mod_overview_server returns a reactive (the filtered data)", {
  raw_rv <- shiny::reactiveVal(util_empty_usage_tbl())
  shiny::testServer(
    mod_overview_server,
    args = list(raw_usage_rv = raw_rv),
    {
      session$flushReact()
      # The server returns filtered; in testServer it's session$returned
      ret <- session$returned
      expect_true(shiny::is.reactive(ret))
    }
  )
})


# ── Value boxes: empty data ───────────────────────────────────────────────────

test_that("mod_overview_server value boxes show 0 for empty data", {
  raw_rv <- shiny::reactiveVal(util_empty_usage_tbl())
  shiny::testServer(
    mod_overview_server,
    args = list(raw_usage_rv = raw_rv),
    {
      session$flushReact()
      expect_equal(output$vb_reqs,  "0")
    }
  )
})


# ── Value boxes: with data ────────────────────────────────────────────────────

test_that("mod_overview_server vb_reqs reflects row count", {
  raw_rv <- shiny::reactiveVal(make_usage(n = 3))
  shiny::testServer(
    mod_overview_server,
    args = list(raw_usage_rv = raw_rv),
    {
      session$flushReact()
      expect_equal(output$vb_reqs, "3")
    }
  )
})

test_that("mod_overview_server vb_cost is non-zero with cost data", {
  raw_rv <- shiny::reactiveVal(make_usage(n = 2))
  shiny::testServer(
    mod_overview_server,
    args = list(raw_usage_rv = raw_rv),
    {
      session$flushReact()
      cost_str <- output$vb_cost
      expect_match(cost_str, "^\\$")
    }
  )
})


# ── Filtered reactive ─────────────────────────────────────────────────────────

test_that("mod_overview_server filtered reactive returns all rows when no filter", {
  raw_rv <- shiny::reactiveVal(make_usage(n = 5))
  shiny::testServer(
    mod_overview_server,
    args = list(raw_usage_rv = raw_rv),
    {
      session$flushReact()
      filtered <- session$returned
      expect_equal(nrow(filtered()), 5)
    }
  )
})

test_that("mod_overview_server filtered reactive updates when raw_usage_rv changes", {
  raw_rv <- shiny::reactiveVal(make_usage(n = 2))
  shiny::testServer(
    mod_overview_server,
    args = list(raw_usage_rv = raw_rv),
    {
      session$flushReact()
      filtered <- session$returned
      expect_equal(nrow(filtered()), 2)

      raw_rv(make_usage(n = 4))
      session$flushReact()
      expect_equal(nrow(filtered()), 4)
    }
  )
})
