#' Primary application server
#'
#' Loads usage data, wires together all module servers, and passes reactive
#' data between them. The overview module owns the filter state and returns
#' the `filtered` reactive consumed by all other modules.
#'
#' @param claude_dirs Named list mapping machine labels to Claude project
#'   directories. Default: `list(local = "~/.claude/projects")`.
#' @return A Shiny server function.
#' @export
app_server <- function(claude_dirs = list(local = "~/.claude/projects")) {
  function(input, output, session) {
    thematic::thematic_shiny()

    logger::log_info(
      "shokenuse server starting — {length(claude_dirs)} source(s) configured",
      namespace = "shokenuse"
    )

    raw_usage <- shiny::reactiveVal(util_empty_usage_tbl())

    load_data <- function() {
      logger::log_info(
        "Loading usage data from: {paste(names(claude_dirs), collapse = ', ')}",
        namespace = "shokenuse"
      )

      tryCatch(
        {
          parts <- mapply(
            function(path, machine) util_read_claude_code(path, machine),
            claude_dirs, names(claude_dirs),
            SIMPLIFY = FALSE
          )
          usage <- dplyr::bind_rows(parts)
          usage <- util_add_cost(usage)
          usage <- dplyr::mutate(usage, date = as.Date(timestamp))
          raw_usage(usage)
          logger::log_info(
            "Data loaded: {nrow(usage)} row(s) ready",
            namespace = "shokenuse"
          )
        },
        error = function(e) {
          logger::log_error(
            "Failed to load data: {conditionMessage(e)}",
            namespace = "shokenuse"
          )
          shiny::showNotification(
            paste("Error loading data:", conditionMessage(e)),
            type     = "error",
            duration = NULL
          )
        }
      )
    }

    load_data()

    shiny::observeEvent(input$refresh_btn, {
      logger::log_info("Dashboard refresh triggered by user", namespace = "shokenuse")
      load_data()
    })

    # Overview module returns the filtered reactive (owns filter state)
    filtered <- mod_overview_server("overview", raw_usage_rv = raw_usage)

    mod_model_server("model",       filtered_rv  = filtered)
    mod_project_server("project",   filtered_rv  = filtered)
    mod_sessions_server("sessions", filtered_rv  = filtered)
    mod_upload_server("upload",     raw_usage_rv = raw_usage)
    mod_pricing_server("pricing")
    mod_api_server("api",           raw_usage_rv = raw_usage)
  }
}
