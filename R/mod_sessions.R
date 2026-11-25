#' Sessions tab module UI
#'
#' @param id Shiny module ID.
#' @export
mod_sessions_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_column_wrap(
      width = "200px", fill = FALSE,
      pvt_value_box("Sessions", ns("vb_total"), "collection", "primary",
                 "Distinct session ids in the filtered data."),
      pvt_value_box("Median cost / session", ns("vb_median"), "cash-stack", "secondary",
                 "Half of the sessions cost less than this."),
      pvt_value_box("Most expensive", ns("vb_max"), "exclamation-triangle", "warning",
                 "Cost of the single most expensive session."),
      pvt_value_box("Outliers", ns("vb_outliers"), "graph-up-arrow", "danger",
                 "Sessions costing more than the mean plus two standard deviations.")
    ),
    bslib::card(
      full_screen = TRUE,
      bslib::card_header("Cost per session (top 30)"),
      shiny::plotOutput(ns("plot"), height = "520px")
    ),
    bslib::card(
      full_screen = TRUE,
      bslib::card_header(
        class = "d-flex justify-content-between align-items-center",
        "Sessions",
        shiny::downloadButton(ns("download"), "Export CSV",
                              class = "btn-sm btn-outline-secondary")
      ),
      shiny::p(class = "text-muted small",
               shiny::tags$code("claude --resume <session>"), " reopens a session."),
      shiny::div(style = "overflow-x: auto;", shiny::tableOutput(ns("tbl")))
    )
  )
}


#' Sessions tab module server
#'
#' @param id Shiny module ID.
#' @param filtered Reactive tibble from [mod_filters_server()].
#' @export
mod_sessions_server <- function(id, filtered) {
  shiny::moduleServer(id, function(input, output, session) {

    sessions <- shiny::reactive(util_summarise_sessions(filtered()))

    pvt_or_dash <- function(f) {
      shiny::renderText({
        s <- sessions()
        if (nrow(s) == 0) "-" else f(s)
      })
    }

    output$vb_total    <- pvt_or_dash(function(s) scales::comma(nrow(s)))
    output$vb_median   <- pvt_or_dash(function(s) scales::dollar(stats::median(s$cost), accuracy = 0.01))
    output$vb_max      <- pvt_or_dash(function(s) scales::dollar(max(s$cost), accuracy = 0.01))
    output$vb_outliers <- pvt_or_dash(function(s) scales::comma(sum(s$outlier)))

    output$plot <- shiny::renderPlot(util_plot_sessions(sessions()), res = 96)

    output$tbl <- shiny::renderTable({
      s <- sessions()
      if (nrow(s) == 0) return(NULL)
      s |>
        dplyr::transmute(
          Session        = session,
          Project        = project,
          Start          = format(start, "%Y-%m-%d %H:%M"),
          Minutes        = scales::comma(minutes, accuracy = 1),
          Prompts        = prompts,
          Tokens         = scales::comma(tokens),
          "Cost (USD)"   = scales::dollar(cost, accuracy = 0.01),
          "First prompt" = first_prompt,
          Outlier        = ifelse(outlier, "yes", "")
        )
    }, striped = TRUE, hover = TRUE, spacing = "s")

    output$download <- shiny::downloadHandler(
      filename = function() paste0("sessions-", Sys.Date(), ".csv"),
      content  = function(file) utils::write.csv(sessions(), file, row.names = FALSE)
    )
  })
}
