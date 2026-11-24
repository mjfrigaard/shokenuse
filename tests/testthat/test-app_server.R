describe("app_server()", {
  it("wires the data, filter, and tab modules together", {
    shiny::testServer(app_server(dir = example_dir()), {
      session$setInputs(`overview-metric` = "tokens")
      expect_match(output$`data-status`$html, "prompts in")
      expect_equal(output$`overview-vb_sessions`, output$`sessions-vb_total`)
    })
  })
})
