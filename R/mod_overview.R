#' Overview tab module UI
#'
#' @param id Shiny module ID.
#' @export
mod_overview_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_column_wrap(
      width = "180px", fill = FALSE,
      .value_box("Tokens", ns("vb_tokens"), "lightning-charge", "primary",
                 "Input, output, cache write, and cache read tokens. Cache reads are most of them."),
      .value_box("Cost (USD)", ns("vb_cost"), "currency-dollar", "warning",
                 "API list price equivalent, not what a subscription bills."),
      .value_box("Prompts", ns("vb_prompts"), "chat-left-text", "success",
                 "One row per prompt in the token-metrics files."),
      .value_box("Sessions", ns("vb_sessions"), "collection", "info",
                 "Distinct Claude Code sessions."),
      .value_box("Cost / prompt", ns("vb_per_prompt"), "calculator", "secondary",
                 "Mean cost per prompt.")
    ),
    bslib::card(
      full_screen = TRUE,
      bslib::card_header(
        class = "d-flex justify-content-between align-items-center",
        "Daily usage by project",
        shiny::radioButtons(ns("metric"), NULL, inline = TRUE,
                            choices = c(Tokens = "tokens", Cost = "cost"))
      ),
      shiny::plotOutput(ns("plot_daily"), height = "450px")
    )
  )
}


#' Overview tab module server
#'
#' @param id Shiny module ID.
#' @param filtered Reactive tibble from [mod_filters_server()].
#' @export
mod_overview_server <- function(id, filtered) {
  shiny::moduleServer(id, function(input, output, session) {
    short <- scales::label_number(scale_cut = scales::cut_short_scale())

    output$vb_tokens <- shiny::renderText(short(sum(filtered()$tokens)))
    output$vb_cost <- shiny::renderText(
      scales::dollar(sum(filtered()$cost, na.rm = TRUE), accuracy = 0.01))
    output$vb_prompts <- shiny::renderText(scales::comma(nrow(filtered())))
    output$vb_sessions <- shiny::renderText(
      scales::comma(dplyr::n_distinct(filtered()$session)))
    output$vb_per_prompt <- shiny::renderText({
      df <- filtered()
      if (nrow(df) == 0) return("-")
      scales::dollar(mean(df$cost, na.rm = TRUE), accuracy = 0.01)
    })

    output$plot_daily <- shiny::renderPlot(
      util_plot_daily(filtered(), input$metric %||% "tokens"),
      res = 96
    )
  })
}


.value_box <- function(title, output_id, icon, theme, tip) {
  bslib::value_box(
    title = bslib::tooltip(
      shiny::tagList(title, " ", bsicons::bs_icon("question-circle", size = "0.75em")),
      tip, placement = "bottom"
    ),
    value    = shiny::textOutput(output_id, inline = TRUE),
    showcase = bsicons::bs_icon(icon),
    showcase_layout = "top right",
    theme    = theme
  )
}
