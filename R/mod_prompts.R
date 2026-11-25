#' Prompts tab module UI
#'
#' @param id Shiny module ID.
#' @export
mod_prompts_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_columns(
      col_widths = c(4, 8),
      bslib::card(
        bslib::card_header("Find prompts"),
        shiny::textInput(ns("search"), "Prompt contains"),
        shiny::radioButtons(ns("metric"), "Rank by", inline = TRUE,
                            choices = c(Tokens = "tokens", Cost = "cost")),
        shiny::numericInput(ns("n"), "Rows", value = 25, min = 5, max = 500, step = 5)
      ),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header("Prompt size distribution"),
        shiny::plotOutput(ns("plot"), height = "260px")
      )
    ),
    bslib::card(
      full_screen = TRUE,
      bslib::card_header("Largest prompts"),
      shiny::div(style = "overflow-x: auto;", shiny::tableOutput(ns("tbl")))
    )
  )
}


#' Prompts tab module server
#'
#' @param id Shiny module ID.
#' @param filtered Reactive tibble from [mod_filters_server()].
#' @export
mod_prompts_server <- function(id, filtered) {
  shiny::moduleServer(id, function(input, output, session) {

    metric <- shiny::reactive(input$metric %||% "tokens")

    matched <- shiny::reactive({
      df <- filtered()
      term <- trimws(input$search %||% "")
      if (nzchar(term)) {
        df <- dplyr::filter(df, grepl(tolower(term), tolower(prompt), fixed = TRUE))
      }
      df
    })

    output$plot <- shiny::renderPlot(util_plot_prompts(matched(), metric()), res = 96)

    output$tbl <- shiny::renderTable({
      df <- matched()
      if (nrow(df) == 0) return(NULL)
      df |>
        dplyr::slice_max(.data[[metric()]], n = input$n %||% 25, with_ties = FALSE) |>
        pvt_format_prompts()
    }, striped = TRUE, hover = TRUE, spacing = "s")
  })
}
