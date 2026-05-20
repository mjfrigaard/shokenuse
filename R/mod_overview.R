#' Overview tab module UI
#'
#' @param id Shiny module ID.
#' @export
mod_overview_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::page_fillable(
    bslib::layout_column_wrap(
      width = "200px",
      fill  = FALSE,
      bslib::value_box(
        title    = "Total Input Tokens",
        value    = shiny::textOutput(ns("vb_input"),  inline = TRUE),
        theme    = "primary",
        showcase = bsicons::bs_icon("arrow-right-circle")
      ),
      bslib::value_box(
        title    = "Total Output Tokens",
        value    = shiny::textOutput(ns("vb_output"), inline = TRUE),
        theme    = "success",
        showcase = bsicons::bs_icon("arrow-left-circle")
      ),
      bslib::value_box(
        title    = "Cache Tokens",
        value    = shiny::textOutput(ns("vb_cache"),  inline = TRUE),
        theme    = "info",
        showcase = bsicons::bs_icon("lightning-charge")
      ),
      bslib::value_box(
        title    = "Est. Cost (USD)",
        value    = shiny::textOutput(ns("vb_cost"),   inline = TRUE),
        theme    = "warning",
        showcase = bsicons::bs_icon("currency-dollar")
      ),
      bslib::value_box(
        title    = "API Requests",
        value    = shiny::textOutput(ns("vb_reqs"),   inline = TRUE),
        theme    = "secondary",
        showcase = bsicons::bs_icon("send")
      )
    ),
    bslib::layout_columns(
      col_widths = c(9, 3),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header("Daily Token Usage"),
        shiny::plotOutput(ns("plot_daily"), height = "340px")
      ),
      bslib::card(
        bslib::card_header("Filters"),
        shiny::dateRangeInput(
          ns("date_range"), "Date range",
          start = Sys.Date() - 90,
          end   = Sys.Date()
        ),
        shiny::selectInput(
          ns("filter_machine"), "Machine",
          choices  = "All",
          selected = "All",
          multiple = TRUE
        ),
        shiny::selectInput(
          ns("filter_source"), "Source",
          choices  = "All",
          selected = "All",
          multiple = TRUE
        ),
        shiny::selectInput(
          ns("stack_var"), "Stack by",
          choices  = c("source", "machine", "model"),
          selected = "source"
        )
      )
    )
  )
}


#' Overview tab module server
#'
#' Owns filter state and computes the filtered reactive returned to the main
#' server for use by all other modules.
#'
#' @param id Shiny module ID.
#' @param raw_usage_rv `reactiveVal` holding the full usage tibble.
#' @return A reactive tibble of filtered usage data.
#' @export
mod_overview_server <- function(id, raw_usage_rv) {
  shiny::moduleServer(id, function(input, output, session) {
    logger::log_debug("mod_overview initialised", namespace = "shokenuse")

    shiny::observe({
      df <- raw_usage_rv()
      if (nrow(df) == 0) return()
      shiny::updateSelectInput(session, "filter_machine",
        choices  = c("All", sort(unique(df$machine))),
        selected = "All"
      )
      shiny::updateSelectInput(session, "filter_source",
        choices  = c("All", sort(unique(df$source))),
        selected = "All"
      )
    })

    filtered <- shiny::reactive({
      df <- raw_usage_rv()
      if (nrow(df) == 0) return(df)

      dr <- input$date_range
      if (!is.null(dr)) {
        df <- dplyr::filter(df, date >= dr[1], date <= dr[2])
      }

      fm <- input$filter_machine
      if (length(fm) > 0 && !("All" %in% fm)) {
        df <- dplyr::filter(df, machine %in% fm)
      }

      fs <- input$filter_source
      if (length(fs) > 0 && !("All" %in% fs)) {
        df <- dplyr::filter(df, source %in% fs)
      }

      df
    })

    totals <- shiny::reactive({
      df <- filtered()
      list(
        input  = sum(df$input_tokens,          na.rm = TRUE),
        output = sum(df$output_tokens,          na.rm = TRUE),
        cache  = sum(df$cache_creation_tokens + df$cache_read_tokens, na.rm = TRUE),
        cost   = if ("cost_usd" %in% names(df)) sum(df$cost_usd, na.rm = TRUE) else 0,
        reqs   = nrow(df)
      )
    })

    output$vb_input  <- shiny::renderText(
      scales::label_number(scale_cut = scales::cut_short_scale())(totals()$input))
    output$vb_output <- shiny::renderText(
      scales::label_number(scale_cut = scales::cut_short_scale())(totals()$output))
    output$vb_cache  <- shiny::renderText(
      scales::label_number(scale_cut = scales::cut_short_scale())(totals()$cache))
    output$vb_cost   <- shiny::renderText(
      scales::dollar(totals()$cost, accuracy = 0.01))
    output$vb_reqs   <- shiny::renderText(
      scales::comma(totals()$reqs))

    output$plot_daily <- shiny::renderPlot({
      df <- filtered()
      if (nrow(df) == 0) return(.empty_plot("No data in selected range"))

      stack_col <- input$stack_var %||% "source"

      daily <- df |>
        dplyr::group_by(date, .data[[stack_col]]) |>
        dplyr::summarise(
          tokens = sum(input_tokens + output_tokens +
                         cache_creation_tokens + cache_read_tokens,
                       na.rm = TRUE),
          .groups = "drop"
        )

      ggplot2::ggplot(
        daily,
        ggplot2::aes(x = date, y = tokens, fill = .data[[stack_col]])
      ) +
        ggplot2::geom_col() +
        ggplot2::scale_y_continuous(
          labels = scales::label_number(scale_cut = scales::cut_short_scale())
        ) +
        ggplot2::scale_x_date(date_breaks = "1 week", date_labels = "%b %d") +
        ggplot2::labs(x = NULL, y = "Tokens", fill = stack_col) +
        ggplot2::theme_minimal(base_size = 13) +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
    })

    filtered
  })
}
