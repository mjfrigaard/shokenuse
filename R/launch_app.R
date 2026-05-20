#' Launch the shokenuse Shiny dashboard
#'
#' Convenience wrapper around [shiny::shinyApp()] that wires together
#' [app_ui()] and [app_server()].
#'
#' @param claude_dirs Named list mapping machine labels to Claude project
#'   directories. Defaults to `list(local = "~/.claude/projects")`.
#'   Add a second entry to show usage from another machine, e.g.:
#'   `list(macOS = "~/.claude/projects", Ubuntu = "/mnt/ubuntu/.claude/projects")`.
#' @param ... Additional arguments passed to [shiny::shinyApp()].
#' @return A Shiny app object (invisibly when run interactively).
#' @export
launch_app <- function(
    claude_dirs = list(local = "~/.claude/projects"),
    ...) {
  shiny::shinyApp(ui = app_ui(), server = app_server(claude_dirs), ...)
}
