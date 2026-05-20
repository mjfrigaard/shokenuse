#' By Model tab module UI
#'
#' @param id Shiny module ID.
#' @export
mod_model_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::page_fillable(
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header("Token Volume by Model"),
        shiny::plotOutput(ns("plot_model_tokens"), height = "360px")
      ),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header("Estimated Cost by Model"),
        shiny::plotOutput(ns("plot_model_cost"), height = "360px")
      )
    ),
    bslib::card(
      full_screen = TRUE,
      bslib::card_header("Model Usage Over Time"),
      shiny::plotOutput(ns("plot_model_time"), height = "300px")
    )
  )
}


#' By Model tab module server
#'
#' @param id Shiny module ID.
#' @param filtered_rv Reactive tibble of filtered usage data (from
#'   [mod_overview_server()]).
#' @export
mod_model_server <- function(id, filtered_rv) {
  shiny::moduleServer(id, function(input, output, session) {
    logger::log_debug("mod_model initialised", namespace = "shokenuse")

    output$plot_model_tokens <- shiny::renderPlot({
      df <- filtered_rv()
      if (nrow(df) == 0) return(.empty_plot())

      by_model <- df |>
        dplyr::group_by(model) |>
        dplyr::summarise(
          input_tokens          = sum(input_tokens,          na.rm = TRUE),
          output_tokens         = sum(output_tokens,         na.rm = TRUE),
          cache_creation_tokens = sum(cache_creation_tokens, na.rm = TRUE),
          cache_read_tokens     = sum(cache_read_tokens,     na.rm = TRUE),
          .groups = "drop"
        ) |>
        tidyr::pivot_longer(
          cols      = c(input_tokens, output_tokens,
                        cache_creation_tokens, cache_read_tokens),
          names_to  = "token_type",
          values_to = "tokens"
        ) |>
        dplyr::mutate(token_type = factor(
          token_type,
          levels = c("input_tokens", "output_tokens",
                     "cache_creation_tokens", "cache_read_tokens"),
          labels = c("Input", "Output", "Cache write", "Cache read")
        ))

      ggplot2::ggplot(by_model, ggplot2::aes(
        x    = tokens,
        y    = stats::reorder(model, tokens),
        fill = token_type
      )) +
        ggplot2::geom_col() +
        ggplot2::scale_x_continuous(
          labels = scales::label_number(scale_cut = scales::cut_short_scale())
        ) +
        ggplot2::labs(x = "Tokens", y = NULL, fill = "Type") +
        ggplot2::theme_minimal(base_size = 13)
    })

    output$plot_model_cost <- shiny::renderPlot({
      df <- filtered_rv()
      if (nrow(df) == 0) return(.empty_plot())

      by_model <- df |>
        dplyr::group_by(model) |>
        dplyr::summarise(cost_usd = sum(cost_usd, na.rm = TRUE), .groups = "drop")

      ggplot2::ggplot(by_model, ggplot2::aes(
        x = cost_usd,
        y = stats::reorder(model, cost_usd)
      )) +
        ggplot2::geom_col() +
        ggplot2::scale_x_continuous(labels = scales::dollar) +
        ggplot2::labs(x = "Estimated cost (USD)", y = NULL) +
        ggplot2::theme_minimal(base_size = 13)
    })

    output$plot_model_time <- shiny::renderPlot({
      df <- filtered_rv()
      if (nrow(df) == 0) return(.empty_plot())

      daily_model <- df |>
        dplyr::group_by(date, model) |>
        dplyr::summarise(
          tokens = sum(input_tokens + output_tokens, na.rm = TRUE),
          .groups = "drop"
        )

      ggplot2::ggplot(daily_model, ggplot2::aes(
        x     = date,
        y     = tokens,
        color = model,
        group = model
      )) +
        ggplot2::geom_line(linewidth = 0.8) +
        ggplot2::scale_y_continuous(
          labels = scales::label_number(scale_cut = scales::cut_short_scale())
        ) +
        ggplot2::labs(x = NULL, y = "Tokens (input + output)", color = "Model") +
        ggplot2::theme_minimal(base_size = 13) +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
    })
  })
}
