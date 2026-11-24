describe("launch_app()", {
  it("returns a shiny.appobj", {
    expect_s3_class(launch_app(dir = example_dir()), "shiny.appobj")
  })

  it("builds the UI", {
    expect_s3_class(app_ui(), "shiny.tag.list")
  })
})
