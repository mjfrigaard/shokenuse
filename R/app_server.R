#' Primary application server
#'
#' Wires together all module servers and passes reactive data between them.
#' The overview module owns the filter state and returns the `filtered`
#' reactive consumed by all other modules. Data is loaded exclusively via
#' the Data tab (Admin API fetch or CSV upload).
#'
#' @return A Shiny server function.
#' @export
app_server <- function() {
  function(input, output, session) {
    thematic::thematic_shiny()

    logger::log_info("shokenuse server starting", namespace = "shokenuse")

    raw_usage <- shiny::reactiveVal(util_empty_usage_tbl())

    mod_data_server("data",          raw_usage_rv = raw_usage)

    # Overview module returns the filtered reactive (owns filter state)
    filtered <- mod_overview_server("overview", raw_usage_rv = raw_usage)

    mod_model_server("model",       filtered_rv  = filtered)
    mod_project_server("project",   filtered_rv  = filtered)
    mod_sessions_server("sessions", filtered_rv  = filtered)
    mod_pricing_server("pricing")
  }
}
