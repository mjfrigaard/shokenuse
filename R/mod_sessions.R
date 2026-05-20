#' Sessions tab module UI
#'
#' @param id Shiny module ID.
#' @export
mod_sessions_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::page_fillable(
    bslib::layout_column_wrap(
      width = "200px",
      fill  = FALSE,
      bslib::value_box(
        title    = "Total Sessions",
        value    = shiny::textOutput(ns("sess_vb_total"),   inline = TRUE),
        theme    = "primary",
        showcase = bsicons::bs_icon("chat-text")
      ),
      bslib::value_box(
        title    = "Median Cost / Session",
        value    = shiny::textOutput(ns("sess_vb_median"),  inline = TRUE),
        theme    = "secondary",
        showcase = bsicons::bs_icon("cash-stack")
      ),
      bslib::value_box(
        title    = "Most Expensive Session",
        value    = shiny::textOutput(ns("sess_vb_max"),     inline = TRUE),
        theme    = "warning",
        showcase = bsicons::bs_icon("exclamation-triangle")
      ),
      bslib::value_box(
        title    = "Outlier Sessions (>2 SD)",
        value    = shiny::textOutput(ns("sess_vb_outliers"), inline = TRUE),
        theme    = "danger",
        showcase = bsicons::bs_icon("graph-up-arrow")
      )
    ),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header(
          "Cost per Session",
          bslib::tooltip(
            bsicons::bs_icon("info-circle", title = "Chart note"),
            "Top 40 sessions by cost. Outliers (>2 SD above mean) are highlighted."
          )
        ),
        shiny::plotOutput(ns("plot_sess_cost"), height = "400px")
      ),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header("Total Tokens per Session"),
        shiny::plotOutput(ns("plot_sess_tokens"), height = "400px")
      )
    ),
    bslib::card(
      full_screen = TRUE,
      bslib::card_header(
        "Session Detail Table",
        shiny::div(
          class = "ms-auto",
          shiny::downloadButton(
            ns("dl_sessions"), "Export CSV",
            class = "btn-sm btn-outline-secondary"
          )
        )
      ),
      shiny::div(
        style = "overflow-x: auto;",
        shiny::tableOutput(ns("tbl_sessions"))
      )
    )
  )
}


#' Sessions tab module server
#'
#' @param id Shiny module ID.
#' @param filtered_rv Reactive tibble of filtered usage data.
#' @export
mod_sessions_server <- function(id, filtered_rv) {
  shiny::moduleServer(id, function(input, output, session) {
    logger::log_debug("mod_sessions initialised", namespace = "shokenuse")

    session_summary <- shiny::reactive({
      df <- filtered_rv()
      if (nrow(df) == 0) return(NULL)
      tryCatch(
        util_summarise_sessions(df),
        error = function(e) {
          logger::log_error(
            "mod_sessions session_summary failed: {conditionMessage(e)}",
            namespace = "shokenuse"
          )
          NULL
        }
      )
    })

    output$sess_vb_total <- shiny::renderText({
      s <- session_summary()
      if (is.null(s)) return("—")
      scales::comma(nrow(s))
    })

    output$sess_vb_median <- shiny::renderText({
      s <- session_summary()
      if (is.null(s)) return("—")
      scales::dollar(stats::median(s$cost_usd), accuracy = 0.001)
    })

    output$sess_vb_max <- shiny::renderText({
      s <- session_summary()
      if (is.null(s)) return("—")
      scales::dollar(max(s$cost_usd), accuracy = 0.01)
    })

    output$sess_vb_outliers <- shiny::renderText({
      s <- session_summary()
      if (is.null(s)) return("—")
      scales::comma(sum(s$outlier))
    })

    output$plot_sess_cost <- shiny::renderPlot({
      s <- session_summary()
      if (is.null(s) || nrow(s) == 0) return(.empty_plot())

      top <- dplyr::slice_head(s, n = 40)

      ggplot2::ggplot(top, ggplot2::aes(
        x    = cost_usd,
        y    = stats::reorder(session_id, cost_usd),
        fill = outlier
      )) +
        ggplot2::geom_col() +
        ggplot2::scale_fill_manual(
          values = c("FALSE" = "#6C63FF", "TRUE" = "#e74c3c"),
          labels = c("FALSE" = "Normal", "TRUE" = "Outlier (>2 SD)"),
          name   = NULL
        ) +
        ggplot2::scale_x_continuous(labels = scales::dollar) +
        ggplot2::scale_y_discrete(
          labels = function(x) ifelse(nchar(x) > 12, paste0(substr(x, 1, 8), "…"), x)
        ) +
        ggplot2::labs(x = "Estimated cost (USD)", y = "Session ID") +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(legend.position = "top")
    })

    output$plot_sess_tokens <- shiny::renderPlot({
      s <- session_summary()
      if (is.null(s) || nrow(s) == 0) return(.empty_plot())

      top <- dplyr::slice_head(s, n = 40)

      top_long <- top |>
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

      ggplot2::ggplot(top_long, ggplot2::aes(
        x    = tokens,
        y    = stats::reorder(session_id, tokens),
        fill = token_type
      )) +
        ggplot2::geom_col() +
        ggplot2::scale_x_continuous(
          labels = scales::label_number(scale_cut = scales::cut_short_scale())
        ) +
        ggplot2::scale_y_discrete(
          labels = function(x) ifelse(nchar(x) > 12, paste0(substr(x, 1, 8), "…"), x)
        ) +
        ggplot2::labs(x = "Tokens", y = "Session ID", fill = "Type") +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(legend.position = "top")
    })

    output$tbl_sessions <- shiny::renderTable({
      s <- session_summary()
      if (is.null(s)) return(data.frame(Status = "No data."))

      s |>
        dplyr::mutate(
          session_id   = paste0(substr(session_id, 1, 8), "…"),
          cost_usd     = scales::dollar(cost_usd, accuracy = 0.001),
          total_tokens = scales::comma(total_tokens),
          duration_min = round(duration_min, 1),
          outlier      = ifelse(outlier, "⚠ yes", "")
        ) |>
        dplyr::select(
          Date             = date,
          Session          = session_id,
          Project          = project,
          Machine          = machine,
          Models           = models,
          Requests         = n_requests,
          "Total tokens"   = total_tokens,
          "Cost (USD)"     = cost_usd,
          "Duration (min)" = duration_min,
          Outlier          = outlier
        )
    }, striped = TRUE, hover = TRUE, bordered = TRUE, spacing = "s", na = "—")

    output$dl_sessions <- shiny::downloadHandler(
      filename = function() paste0("sessions-", Sys.Date(), ".csv"),
      content  = function(file) {
        s <- session_summary()
        utils::write.csv(if (is.null(s)) data.frame() else s, file, row.names = FALSE)
      }
    )
  })
}
