#' By Project tab module UI
#'
#' @param id Shiny module ID.
#' @export
mod_project_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::page_fillable(
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header("Token Usage by Project"),
        shiny::plotOutput(ns("plot_project_tokens"), height = "420px")
      ),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header("Cost by Project"),
        shiny::plotOutput(ns("plot_project_cost"), height = "420px")
      )
    )
  )
}


#' By Project tab module server
#'
#' @param id Shiny module ID.
#' @param filtered_rv Reactive tibble of filtered usage data.
#' @export
mod_project_server <- function(id, filtered_rv) {
  shiny::moduleServer(id, function(input, output, session) {
    logger::log_debug("mod_project initialised", namespace = "shokenuse")

    output$plot_project_tokens <- shiny::renderPlot({
      df <- filtered_rv()
      if (nrow(df) == 0) return(.empty_plot())

      by_proj <- df |>
        dplyr::filter(!is.na(project), nzchar(project)) |>
        dplyr::group_by(project) |>
        dplyr::summarise(
          tokens = sum(input_tokens + output_tokens +
                         cache_creation_tokens + cache_read_tokens,
                       na.rm = TRUE),
          .groups = "drop"
        ) |>
        dplyr::slice_max(tokens, n = 20)

      ggplot2::ggplot(by_proj, ggplot2::aes(
        x = tokens,
        y = stats::reorder(project, tokens)
      )) +
        ggplot2::geom_col() +
        ggplot2::scale_x_continuous(
          labels = scales::label_number(scale_cut = scales::cut_short_scale())
        ) +
        ggplot2::labs(x = "Total tokens", y = NULL) +
        ggplot2::theme_minimal(base_size = 12)
    }, res = 96)

    output$plot_project_cost <- shiny::renderPlot({
      df <- filtered_rv()
      if (nrow(df) == 0) return(.empty_plot())

      by_proj <- df |>
        dplyr::filter(!is.na(project), nzchar(project)) |>
        dplyr::group_by(project) |>
        dplyr::summarise(cost_usd = sum(cost_usd, na.rm = TRUE), .groups = "drop") |>
        dplyr::slice_max(cost_usd, n = 20)

      ggplot2::ggplot(by_proj, ggplot2::aes(
        x = cost_usd,
        y = stats::reorder(project, cost_usd)
      )) +
        ggplot2::geom_col() +
        ggplot2::scale_x_continuous(labels = scales::dollar) +
        ggplot2::labs(x = "Estimated cost (USD)", y = NULL) +
        ggplot2::theme_minimal(base_size = 12)
    }, res = 96)
  })
}
