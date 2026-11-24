describe("util_read_token_metrics()", {
  it("reads every daily file in a folder", {
    df <- util_read_token_metrics(example_dir())
    expect_named(df, names(util_empty_metrics_tbl()))
    expect_s3_class(df$date, "POSIXct")
    expect_s3_class(df$day, "Date")
    expect_type(df$tokens, "double")
    expect_equal(length(unique(df$day)), 7)
    expect_false(is.unsorted(df$date))
  })

  it("reads a vector of files", {
    files <- fs::dir_ls(example_dir())[1:2]
    df <- util_read_token_metrics(files)
    expect_equal(length(unique(df$day)), 2)
  })

  it("turns blank url and cost into NA", {
    f <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("date,session,project,directory,url,prompt,tokens,cost",
                 "2026-11-01T10:00:00,s1,p,/d,,hi,10,"), f)
    df <- util_read_token_metrics(f)
    expect_true(is.na(df$url))
    expect_true(is.na(df$cost))
  })

  it("returns an empty tibble for an empty folder", {
    d <- withr::local_tempdir()
    expect_equal(util_read_token_metrics(d), util_empty_metrics_tbl())
  })

  it("errors on files without the token-metrics columns", {
    f <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("a,b", "1,2"), f)
    expect_error(util_read_token_metrics(f), "Missing: date")
  })
})

describe("util_combine_metrics()", {
  it("drops duplicate rows", {
    df <- make_metrics()
    expect_equal(nrow(util_combine_metrics(df, df)), 3)
  })
})

describe("util_summarise_metrics()", {
  it("sums tokens and cost and counts prompts and sessions", {
    s <- util_summarise_metrics(make_metrics(tokens = c(100, 100, 300)), by = "project")
    expect_equal(s$project, c("b", "a"))
    expect_equal(s$tokens, c(300, 200))
    expect_equal(s$prompts, c(1L, 2L))
    expect_equal(s$cost, c(0.3, 0.3))
  })

  it("ignores missing cost", {
    s <- util_summarise_metrics(make_metrics(cost = c(NA, 1, 2)), by = "day")
    expect_equal(s$cost, 3)
  })
})

describe("util_summarise_sessions()", {
  it("returns one row per session sorted by cost", {
    s <- util_summarise_sessions(make_metrics(cost = c(0.1, 0.1, 0.5)))
    expect_equal(s$session, c("s2", "s1"))
    expect_equal(s$prompts, c(1L, 2L))
    expect_equal(s$minutes, c(0, 10))
    expect_equal(s$first_prompt[2], "prompt 1")
  })

  it("flags sessions more than 2 SD above the mean", {
    n <- 12
    df <- make_metrics(session = paste0("s", 1:n), project = rep("a", n),
                       tokens = rep(1, n), cost = c(rep(1, n - 1), 50))
    s <- util_summarise_sessions(df)
    expect_equal(s$session[s$outlier], "s12")
  })

  it("flags no outliers when every session costs the same", {
    s <- util_summarise_sessions(make_metrics(session = c("s1", "s2", "s3"),
                                              cost = c(1, 1, 1)))
    expect_false(any(s$outlier))
  })

  it("handles empty input", {
    s <- util_summarise_sessions(util_empty_metrics_tbl())
    expect_equal(nrow(s), 0)
    expect_true("outlier" %in% names(s))
  })
})

describe("util_lump_projects()", {
  it("keeps the top n projects and lumps the rest", {
    df <- make_metrics(project = c("a", "b", "c"), tokens = c(1, 5, 9))
    expect_equal(util_lump_projects(df, n = 2)$project, c("other", "b", "c"))
  })
})

describe("util_log_threshold()", {
  it("sets the package log level", {
    old <- logger::log_threshold(namespace = "shokenuse")
    withr::defer(logger::log_threshold(old, namespace = "shokenuse"))
    expect_null(util_log_threshold("WARN"))
    expect_equal(logger::log_threshold(namespace = "shokenuse"), logger::WARN, ignore_attr = TRUE)
  })
})
