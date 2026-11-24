describe("plot helpers", {
  df <- make_metrics()

  it("return ggplot objects", {
    expect_s3_class(util_plot_daily(df, "cost"), "ggplot")
    expect_s3_class(util_plot_rank(util_summarise_metrics(df, "project"), "project"), "ggplot")
    expect_s3_class(util_plot_sessions(util_summarise_sessions(df)), "ggplot")
    expect_s3_class(util_plot_prompts(df), "ggplot")
  })

  it("return a placeholder plot for empty data", {
    empty <- util_empty_metrics_tbl()
    expect_s3_class(util_plot_daily(empty), "ggplot")
    expect_s3_class(util_plot_prompts(empty), "ggplot")
    expect_s3_class(util_plot_sessions(util_summarise_sessions(empty)), "ggplot")
    expect_s3_class(util_plot_rank(util_summarise_metrics(empty, "project"), "project"), "ggplot")
  })

  it("reject unknown metrics", {
    expect_error(util_plot_daily(df, "nope"))
  })
})
