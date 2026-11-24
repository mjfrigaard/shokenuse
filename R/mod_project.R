#' By Project tab module UI
#'
#' @param id Shiny module ID.
#' @export
mod_project_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header("Tokens by project"),
        shiny::plotOutput(ns("plot_tokens"))
      ),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header("Cost by project"),
        shiny::plotOutput(ns("plot_cost"))
      )
    ),
    bslib::card(
      bslib::card_header("Projects"),
      shiny::div(style = "overflow-x: auto;", shiny::tableOutput(ns("tbl")))
    )
  )
}


#' By Project tab module server
#'
#' @param id Shiny module ID.
#' @param filtered Reactive tibble from [mod_filters_server()].
#' @export
mod_project_server <- function(id, filtered) {
  shiny::moduleServer(id, function(input, output, session) {

    by_project <- shiny::reactive(
      util_summarise_metrics(filtered(), by = c("project", "url"))
    )

    output$plot_tokens <- shiny::renderPlot(
      util_plot_rank(by_project(), "project", "tokens"), res = 96)
    output$plot_cost <- shiny::renderPlot(
      util_plot_rank(by_project(), "project", "cost"), res = 96)

    output$tbl <- shiny::renderTable({
      df <- by_project()
      if (nrow(df) == 0) return(NULL)
      df |>
        dplyr::transmute(
          Project      = project,
          Remote       = dplyr::coalesce(url, ""),
          Prompts      = prompts,
          Sessions     = sessions,
          Tokens       = scales::comma(tokens),
          "Cost (USD)" = scales::dollar(cost, accuracy = 0.01)
        )
    }, striped = TRUE, hover = TRUE, spacing = "s")
  })
}
