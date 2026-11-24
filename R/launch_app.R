#' Launch the shokenuse Shiny dashboard
#'
#' @param dir Folder of daily token-metrics CSVs read at startup. Defaults to
#'   [util_metrics_dir()]. Use
#'   `system.file("extdata", "token-metrics", package = "shokenuse")` for the
#'   example data.
#' @param options A list of options passed to [shiny::shinyApp()].
#' @return A `shiny.appobj`.
#' @export
launch_app <- function(dir = util_metrics_dir(), options = list()) {
  shiny::shinyApp(ui = app_ui(dir), server = app_server(dir), options = options)
}
