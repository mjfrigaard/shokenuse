describe("mod_data_server()", {
  it("reads the folder at startup", {
    shiny::testServer(mod_data_server, args = list(dir = example_dir()), {
      expect_gt(nrow(session$returned()), 0)
      expect_match(as.character(output$status$html), "prompts in")
    })
  })

  it("adds uploaded files without duplicating rows", {
    shiny::testServer(mod_data_server, args = list(dir = example_dir()), {
      n <- nrow(session$returned())
      f <- fs::dir_ls(example_dir())[1]
      session$setInputs(upload = data.frame(name = "x.csv", datapath = f))
      expect_equal(nrow(session$returned()), n)
    })
  })

  it("returns an empty tibble for a missing folder", {
    shiny::testServer(mod_data_server, args = list(dir = withr::local_tempdir()), {
      expect_equal(nrow(session$returned()), 0)
    })
  })
})

describe("mod_data_server() errors and empty state", {
  it("keeps the folder data when an upload has the wrong columns", {
    bad <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("a,b", "1,2"), bad)
    shiny::testServer(mod_data_server, args = list(dir = example_dir()), {
      n <- nrow(session$returned())
      session$setInputs(upload = data.frame(name = "bad.csv", datapath = bad))
      expect_equal(nrow(session$returned()), n)
    })
  })

  it("explains that no data is loaded", {
    shiny::testServer(mod_data_server, args = list(dir = withr::local_tempdir()), {
      expect_match(as.character(output$status$html), "No data loaded")
      expect_null(output$preview)
    })
  })
})
