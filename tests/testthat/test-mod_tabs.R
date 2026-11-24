describe("analysis tab modules", {
  df <- shiny::reactive(make_metrics())

  it("mod_overview_server() renders totals", {
    shiny::testServer(mod_overview_server, args = list(filtered = df), {
      session$setInputs(metric = "cost")
      expect_equal(output$vb_tokens, "600")
      expect_equal(output$vb_cost, "$0.60")
      expect_equal(output$vb_prompts, "3")
      expect_equal(output$vb_sessions, "2")
      expect_type(output$plot_daily, "list")
    })
  })

  it("mod_sessions_server() renders session totals", {
    shiny::testServer(mod_sessions_server, args = list(filtered = df), {
      expect_equal(output$vb_total, "2")
      expect_equal(output$vb_max, "$0.30")
      expect_match(output$tbl, "s1")
    })
  })

  it("mod_sessions_server() shows a dash when empty", {
    empty <- shiny::reactive(util_empty_metrics_tbl())
    shiny::testServer(mod_sessions_server, args = list(filtered = empty), {
      expect_equal(output$vb_total, "-")
    })
  })

  it("mod_project_server() lists projects", {
    shiny::testServer(mod_project_server, args = list(filtered = df), {
      expect_match(output$tbl, "<td> a </td>")
    })
  })

  it("mod_prompts_server() searches prompts case insensitively", {
    shiny::testServer(mod_prompts_server, args = list(filtered = df), {
      session$setInputs(search = "PROMPT 2", metric = "tokens", n = 10)
      expect_equal(nrow(matched()), 1)
      expect_match(output$tbl, "prompt 2")
    })
  })
})

describe("analysis tab modules with no data", {
  empty <- shiny::reactive(util_empty_metrics_tbl())

  it("mod_overview_server() shows zero totals and a dash", {
    shiny::testServer(mod_overview_server, args = list(filtered = empty), {
      expect_equal(output$vb_prompts, "0")
      expect_equal(output$vb_per_prompt, "-")
    })
  })

  it("mod_project_server() renders no table", {
    shiny::testServer(mod_project_server, args = list(filtered = empty), {
      expect_null(output$tbl)
    })
  })

  it("mod_prompts_server() renders no table", {
    shiny::testServer(mod_prompts_server, args = list(filtered = empty), {
      session$setInputs(search = "", metric = "tokens", n = 10)
      expect_null(output$tbl)
    })
  })
})
