# Take the app screenshots used in the vignettes (vignettes/images/*.png).
#
# Run from the package root:
#   CHROMOTE_CHROME=/path/to/chrome Rscript --no-init-file dev/screenshots.R
#
# The app runs on the example data in inst/extdata/token-metrics. HOME is
# pointed at a temporary folder holding a copy of that data, so the Data tab
# shows the default ~/.cache/token-metrics path and no real prompts.
# Needs callr, chromote, and pkgload.

pkg <- normalizePath(".")
stopifnot(file.exists(file.path(pkg, "DESCRIPTION")))
out <- file.path(pkg, "vignettes", "images")
dir.create(out, showWarnings = FALSE)

home <- file.path(tempdir(), "home")
data_dir <- file.path(home, ".cache", "token-metrics")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
invisible(file.copy(
  list.files(file.path(pkg, "inst", "extdata", "token-metrics"), full.names = TRUE),
  data_dir
))

port <- 8765
app <- callr::r_bg(
  function(pkg, port) {
    pkgload::load_all(pkg, quiet = TRUE)
    shiny::runApp(launch_app(), port = port, launch.browser = FALSE)
  },
  args = list(pkg = pkg, port = port),
  user_profile = FALSE,
  env = c(callr::rcmd_safe_env(), HOME = home, R_LIBS = paste(.libPaths(), collapse = ":"))
)
on.exit(app$kill(), add = TRUE)

url <- sprintf("http://127.0.0.1:%d", port)
for (i in 1:60) {
  ok <- tryCatch({ readLines(url, warn = FALSE); TRUE }, error = function(e) FALSE)
  if (ok) break
  Sys.sleep(0.5)
}
stopifnot("app did not start" = ok)

b <- chromote::ChromoteSession$new(width = 1400, height = 1000)
invisible(b$Page$navigate(url))
invisible(b$Page$loadEventFired())
Sys.sleep(3)

tabs <- c(data = "Data", overview = "Overview", `by-project` = "By Project",
          sessions = "Sessions", prompts = "Prompts")
for (f in names(tabs)) {
  b$Runtime$evaluate(sprintf(
    "document.querySelector(\"a.nav-link[data-value='%s']\").click()", tabs[[f]]))
  Sys.sleep(3)
  # The main panel scrolls, not the page, so measure the tallest element.
  h <- b$Runtime$evaluate(paste0(
    "Math.max(...Array.from(document.querySelectorAll('*'), ",
    "e => e.scrollHeight + e.getBoundingClientRect().top))"))$result$value
  b$set_viewport_size(1400, min(h, 1800))
  Sys.sleep(2)
  b$screenshot(file.path(out, paste0(f, ".png")), selector = "html", show = FALSE)
  b$set_viewport_size(1400, 1000)
}
b$close()
cat(list.files(out), sep = "\n")
