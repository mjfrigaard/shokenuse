#' Filters sidebar module UI
#'
#' Date range and project filters shared by every analysis tab.
#'
#' @param id Shiny module ID.
#' @export
mod_filters_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::sidebar(
    title = "Filters",
    shiny::dateRangeInput(ns("days"), "Date range"),
    shiny::selectizeInput(
      ns("projects"), "Projects", choices = NULL, multiple = TRUE,
      options = list(placeholder = "All projects")
    )
  )
}


#' Filters sidebar module server
#'
#' @param id Shiny module ID.
#' @param metrics Reactive tibble from [mod_data_server()].
#' @return A reactive tibble of filtered metrics.
#' @export
mod_filters_server <- function(id, metrics) {
  shiny::moduleServer(id, function(input, output, session) {

    shiny::observe({
      df <- metrics()
      if (nrow(df) == 0) return()
      shiny::updateDateRangeInput(
        session, "days",
        start = min(df$day), end = max(df$day),
        min = min(df$day), max = max(df$day)
      )
      shiny::updateSelectizeInput(
        session, "projects", choices = sort(unique(df$project)),
        selected = shiny::isolate(input$projects)
      )
    })

    shiny::reactive({
      df <- metrics()
      days <- input$days
      if (length(days) == 2 && !anyNA(days)) {
        df <- dplyr::filter(df, day >= days[1], day <= days[2])
      }
      if (length(input$projects) > 0) {
        df <- dplyr::filter(df, project %in% input$projects)
      }
      df
    })
  })
}
