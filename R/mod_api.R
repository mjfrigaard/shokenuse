#' API Data tab module UI
#'
#' Provides a form for fetching token usage directly from the Anthropic
#' Admin API and optionally merging results into the dashboard data.
#'
#' @param id Shiny module ID.
#' @export
mod_api_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_columns(
    col_widths = c(4, 8),
    bslib::card(
      bslib::card_header("Fetch from Admin API"),
      shiny::p(
        shiny::tags$strong("Requires an Admin API key"),
        " (", shiny::tags$code("sk-ant-admin..."), ") from an",
        shiny::tags$em("organization"), " account — not available for",
        "individual accounts."
      ),
      shiny::passwordInput(
        ns("admin_key"), "Admin API Key",
        placeholder = "sk-ant-admin..."
      ),
      shiny::dateRangeInput(
        ns("api_date_range"), "Date range",
        start = Sys.Date() - 30,
        end   = Sys.Date()
      ),
      shiny::selectInput(
        ns("bucket_width"), "Granularity",
        choices  = c("Daily" = "1d", "Hourly" = "1h", "Minute" = "1m"),
        selected = "1d"
      ),
      shiny::checkboxGroupInput(
        ns("group_by"), "Group by",
        choices = c(
          "Model"        = "model",
          "Workspace"    = "workspace_id",
          "API key"      = "api_key_id",
          "Service tier" = "service_tier"
        ),
        selected = "model"
      ),
      shiny::actionButton(ns("fetch_btn"), "Fetch Usage", class = "btn-primary w-100"),
      shiny::hr(),
      shiny::checkboxInput(ns("merge_data"), "Include in dashboard filters", value = FALSE),
      shiny::actionButton(
        ns("merge_btn"), "Merge into dashboard",
        class = "btn-outline-secondary btn-sm w-100"
      )
    ),
    bslib::card(
      full_screen = TRUE,
      bslib::card_header("API Usage Results"),
      shiny::uiOutput(ns("api_status")),
      shiny::plotOutput(ns("plot_api_usage"), height = "300px"),
      shiny::div(
        style = "overflow-x: auto;",
        shiny::tableOutput(ns("tbl_api_usage"))
      )
    )
  )
}


#' API Data tab module server
#'
#' @param id Shiny module ID.
#' @param raw_usage_rv `reactiveVal` holding the full usage tibble. API data
#'   can be merged into this value when the user confirms.
#' @export
mod_api_server <- function(id, raw_usage_rv) {
  shiny::moduleServer(id, function(input, output, session) {
    logger::log_debug("mod_api initialised", namespace = "shokenuse")

    api_data <- shiny::reactiveVal(NULL)

    shiny::observeEvent(input$fetch_btn, {
      shiny::req(nzchar(input$admin_key))
      logger::log_info(
        "Admin API fetch requested: {input$api_date_range[1]} to {input$api_date_range[2]} [{input$bucket_width}]",
        namespace = "shokenuse"
      )
      result <- tryCatch(
        util_fetch_usage(
          starting_at  = paste0(input$api_date_range[1], "T00:00:00Z"),
          ending_at    = paste0(input$api_date_range[2], "T23:59:59Z"),
          bucket_width = input$bucket_width,
          group_by     = input$group_by,
          api_key      = input$admin_key
        ),
        error = function(e) {
          logger::log_error(
            "Admin API fetch failed: {conditionMessage(e)}",
            namespace = "shokenuse"
          )
          shiny::showNotification(
            paste("API error:", conditionMessage(e)),
            type = "error"
          )
          NULL
        }
      )
      api_data(result)
    })

    output$api_status <- shiny::renderUI({
      d <- api_data()
      if (is.null(d)) {
        return(shiny::p("No data fetched yet.", class = "text-muted small"))
      }
      shiny::p(
        class = "text-success small",
        paste("Fetched", nrow(d), "records.")
      )
    })

    output$plot_api_usage <- shiny::renderPlot({
      d <- api_data()
      if (is.null(d) || nrow(d) == 0) return(.empty_plot("Fetch data to see chart"))

      fill_col <- if ("model" %in% names(d)) "model" else NULL
      d$ts <- as.POSIXct(d$timestamp_bucket)

      p <- ggplot2::ggplot(d, ggplot2::aes(x = ts, y = input_tokens))
      if (!is.null(fill_col)) {
        p <- p + ggplot2::aes(fill = .data[[fill_col]])
      }
      p +
        ggplot2::geom_col() +
        ggplot2::scale_y_continuous(
          labels = scales::label_number(scale_cut = scales::cut_short_scale())
        ) +
        ggplot2::labs(x = NULL, y = "Input tokens", fill = "Model") +
        ggplot2::theme_minimal(base_size = 13)
    })

    output$tbl_api_usage <- shiny::renderTable({
      d <- api_data()
      if (is.null(d)) return(data.frame(Status = "No data fetched yet."))
      d
    })

    shiny::observeEvent(input$merge_btn, {
      shiny::req(input$merge_data, !is.null(api_data()))
      d <- api_data()
      if (!"model" %in% names(d)) d$model <- "unknown"

      new_rows <- tibble::tibble(
        timestamp             = as.POSIXct(d$timestamp_bucket, tz = "UTC"),
        machine               = "api",
        source                = "anthropic_api",
        project               = NA_character_,
        session_id            = NA_character_,
        model                 = d$model,
        input_tokens          = as.integer(d$input_tokens          %||% 0L),
        cache_creation_tokens = as.integer(
          d$cache_creation_input_tokens %||% 0L),
        cache_read_tokens     = as.integer(
          d$cache_read_input_tokens     %||% 0L),
        output_tokens         = as.integer(d$output_tokens          %||% 0L)
      )

      combined <- util_combine_usage(raw_usage_rv(), new_rows)
      raw_usage_rv(combined)
      shiny::showNotification("API data merged into dashboard.", type = "message")
    })
  })
}
