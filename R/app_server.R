#' Primary application server
#'
#' The Data module reads the token-metrics folder, the Filters module
#' applies the sidebar filters, and every analysis tab receives the
#' filtered reactive.
#'
#' @param dir Token-metrics folder read at startup.
#' @return A Shiny server function.
#' @export
app_server <- function(dir = util_metrics_dir()) {
  function(input, output, session) {
    thematic::thematic_shiny()
    logger::log_info("shokenuse server starting", namespace = "shokenuse")

    metrics  <- mod_data_server("data", dir = dir)
    filtered <- mod_filters_server("filters", metrics = metrics)

    mod_overview_server("overview", filtered = filtered)
    mod_project_server("project",   filtered = filtered)
    mod_sessions_server("sessions", filtered = filtered)
    mod_prompts_server("prompts",   filtered = filtered)
  }
}
