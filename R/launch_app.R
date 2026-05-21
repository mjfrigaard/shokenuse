#' Launch the shokenuse Shiny dashboard
#'
#' Convenience wrapper around [shiny::shinyApp()] that wires together
#' [app_ui()] and [app_server()]. Load data via the Data tab using an
#' Anthropic Admin API key or by uploading a CSV file.
#'
#' @param ... Additional arguments passed to [shiny::shinyApp()].
#' @return A Shiny app object (invisibly when run interactively).
#' @export
launch_app <- function(...) {
  shiny::shinyApp(ui = app_ui(), server = app_server(), ...)
}
