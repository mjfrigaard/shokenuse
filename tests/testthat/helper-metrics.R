example_dir <- function() {
  system.file("extdata", "token-metrics", package = "shokenuse")
}

make_metrics <- function(session = c("s1", "s1", "s2"),
                         project = c("a", "a", "b"),
                         tokens = c(100, 200, 300),
                         cost = c(0.1, 0.2, 0.3)) {
  date <- as.POSIXct("2026-11-01 09:00:00") + seq_along(session) * 600
  tibble::tibble(
    date = date, day = as.Date(format(date, "%Y-%m-%d")),
    session = session, project = project,
    directory = paste0("/tmp/", project), url = NA_character_,
    prompt = paste("prompt", seq_along(session)),
    tokens = tokens, cost = cost
  )
}
