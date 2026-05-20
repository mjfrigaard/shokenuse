#' Pricing tab module UI
#'
#' @param id Shiny module ID.
#' @export
mod_pricing_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_columns(
    col_widths = c(8, 4),
    bslib::card(
      bslib::card_header("Current Model Pricing (USD per million tokens)"),
      shiny::tableOutput(ns("pricing_table"))
    ),
    bslib::card(
      bslib::card_header("Note"),
      shiny::p(
        "Prices are estimates based on Anthropic's published rates.",
        "Cache-read tokens are typically much cheaper than standard input.",
        "Claude Code compresses context aggressively, so cache tokens can",
        "make up the majority of your token volume."
      ),
      shiny::p(
        shiny::tags$a(
          "Check current pricing →",
          href   = "https://www.anthropic.com/pricing",
          target = "_blank"
        )
      )
    )
  )
}


#' Pricing tab module server
#'
#' @param id Shiny module ID.
#' @export
mod_pricing_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    logger::log_debug("mod_pricing initialised", namespace = "shokenuse")
    output$pricing_table <- shiny::renderTable({
      util_model_pricing() |>
        dplyr::rename(
          Model                = model,
          "Input ($/M)"        = input_pm,
          "Output ($/M)"       = output_pm,
          "Cache write ($/M)"  = cache_write_pm,
          "Cache read ($/M)"   = cache_read_pm
        )
    }, digits = 2)
  })
}
