describe("mod_filters_server()", {
  it("filters by project and date range", {
    df <- make_metrics()
    shiny::testServer(mod_filters_server, args = list(metrics = shiny::reactive(df)), {
      session$setInputs(days = as.Date(c("2026-11-01", "2026-11-01")), projects = "b")
      expect_equal(session$returned()$project, "b")
      session$setInputs(projects = NULL, days = as.Date(c("2026-10-01", "2026-10-02")))
      expect_equal(nrow(session$returned()), 0)
    })
  })

  it("passes all rows through with no filters set", {
    df <- make_metrics()
    shiny::testServer(mod_filters_server, args = list(metrics = shiny::reactive(df)), {
      expect_equal(nrow(session$returned()), 3)
    })
  })
})

describe("mod_filters_server() with no data", {
  it("returns an empty tibble", {
    empty <- shiny::reactive(util_empty_metrics_tbl())
    shiny::testServer(mod_filters_server, args = list(metrics = empty), {
      expect_equal(nrow(session$returned()), 0)
    })
  })
})
