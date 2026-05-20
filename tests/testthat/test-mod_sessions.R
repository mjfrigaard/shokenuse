library(shokenuse)

make_session_usage <- function(session_id = "s1", cost = 0.05) {
  tibble::tibble(
    timestamp             = as.POSIXct("2026-05-01 10:00:00", tz = "UTC"),
    machine               = "test",
    source                = "claude_code",
    project               = "projects/test",
    session_id            = session_id,
    model                 = "claude-opus-4",
    input_tokens          = 100L,
    cache_creation_tokens = 0L,
    cache_read_tokens     = 0L,
    output_tokens         = 50L,
    cost_usd              = cost,
    date                  = as.Date("2026-05-01")
  )
}

# ── Empty data ────────────────────────────────────────────────────────────────

test_that("mod_sessions_server value boxes show dash for empty data", {
  shiny::testServer(
    mod_sessions_server,
    args = list(filtered_rv = shiny::reactive(util_empty_usage_tbl())),
    {
      session$flushReact()
      expect_equal(output$sess_vb_total,    "—")
      expect_equal(output$sess_vb_median,   "—")
      expect_equal(output$sess_vb_max,      "—")
      expect_equal(output$sess_vb_outliers, "—")
    }
  )
})


# ── Single session ────────────────────────────────────────────────────────────

test_that("mod_sessions_server sess_vb_total is '1' for one session", {
  usage <- make_session_usage("abc123", cost = 0.10)
  shiny::testServer(
    mod_sessions_server,
    args = list(filtered_rv = shiny::reactive(usage)),
    {
      session$flushReact()
      expect_equal(output$sess_vb_total, "1")
    }
  )
})

test_that("mod_sessions_server outlier count is '0' for one session", {
  usage <- make_session_usage("abc123", cost = 99.99)
  shiny::testServer(
    mod_sessions_server,
    args = list(filtered_rv = shiny::reactive(usage)),
    {
      session$flushReact()
      expect_equal(output$sess_vb_outliers, "0")
    }
  )
})


# ── Multiple sessions ─────────────────────────────────────────────────────────

test_that("mod_sessions_server sess_vb_total counts all sessions", {
  usage <- dplyr::bind_rows(
    make_session_usage("s1", 0.01),
    make_session_usage("s2", 0.02),
    make_session_usage("s3", 0.03)
  )
  shiny::testServer(
    mod_sessions_server,
    args = list(filtered_rv = shiny::reactive(usage)),
    {
      session$flushReact()
      expect_equal(output$sess_vb_total, "3")
    }
  )
})

test_that("mod_sessions_server reactive updates when filtered_rv changes", {
  usage_rv <- shiny::reactiveVal(make_session_usage("s1", 0.05))

  shiny::testServer(
    mod_sessions_server,
    args = list(filtered_rv = shiny::reactive(usage_rv())),
    {
      session$flushReact()
      expect_equal(output$sess_vb_total, "1")

      usage_rv(dplyr::bind_rows(
        make_session_usage("s1", 0.05),
        make_session_usage("s2", 0.10)
      ))
      session$flushReact()
      expect_equal(output$sess_vb_total, "2")
    }
  )
})
