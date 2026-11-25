#' Data tab module UI
#'
#' Reads the token-metrics folder and accepts uploaded token-metrics CSVs.
#'
#' @param id Shiny module ID.
#' @param dir Default token-metrics folder shown in the folder input.
#' @export
mod_data_ui <- function(id, dir = util_metrics_dir()) {
  ns <- shiny::NS(id)
  bslib::layout_columns(
    col_widths = c(4, 8),
    bslib::card(
      bslib::card_header("Load Data"),
      shiny::textInput(ns("dir"), "Token-metrics folder", value = dir),
      shiny::actionButton(
        ns("reload"), "Reload folder",
        icon = shiny::icon("rotate"), class = "btn-primary w-100"
      ),
      shiny::p(
        class = "text-muted small mt-2",
        "Reads every ", shiny::tags$code("YYYY-MM-DD-token-metrics.csv"),
        " in the folder. The files are written hourly by ",
        shiny::tags$code("token-metrics.py"), "."
      ),
      shiny::hr(),
      shiny::fileInput(
        ns("upload"), "Add token-metrics CSVs",
        accept = ".csv", multiple = TRUE, buttonLabel = "Browse"
      ),
      shiny::p(
        class = "text-muted small mb-0",
        "Columns: ",
        shiny::tags$code("date, session, project, directory, url, prompt, tokens, cost"),
        ". Uploaded rows are added to the folder rows; duplicates are dropped."
      )
    ),
    bslib::card(
      bslib::card_header("Latest prompts"),
      shiny::uiOutput(ns("status")),
      shiny::div(style = "overflow-x: auto;", shiny::tableOutput(ns("preview")))
    )
  )
}


#' Data tab module server
#'
#' @param id Shiny module ID.
#' @param dir Default token-metrics folder, used until the folder input is set.
#' @return A reactive tibble from [util_read_token_metrics()].
#' @export
mod_data_server <- function(id, dir = util_metrics_dir()) {
  shiny::moduleServer(id, function(input, output, session) {

    from_dir <- shiny::reactive({
      path <- input$dir %||% dir
      pvt_safe_read(path, session)
    }) |>
      shiny::bindEvent(input$reload, ignoreNULL = FALSE)

    uploaded <- shiny::reactiveVal(util_empty_metrics_tbl())

    shiny::observeEvent(input$upload, {
      new <- pvt_safe_read(input$upload$datapath, session)
      uploaded(util_combine_metrics(uploaded(), new))
    })

    metrics <- shiny::reactive(util_combine_metrics(from_dir(), uploaded()))

    output$status <- shiny::renderUI({
      df <- metrics()
      if (nrow(df) == 0) {
        return(shiny::p(class = "text-muted small",
                        "No data loaded. Check the folder path or upload a CSV."))
      }
      shiny::p(
        class = "text-muted small mb-1",
        sprintf("%s prompts in %s sessions across %s projects, %s to %s.",
                scales::comma(nrow(df)),
                scales::comma(dplyr::n_distinct(df$session)),
                dplyr::n_distinct(df$project),
                min(df$day), max(df$day))
      )
    })

    output$preview <- shiny::renderTable({
      df <- metrics()
      if (nrow(df) == 0) return(NULL)
      df |>
        dplyr::slice_max(date, n = 20, with_ties = FALSE) |>
        pvt_format_prompts()
    }, striped = TRUE, hover = TRUE, spacing = "s")

    metrics
  })
}


pvt_safe_read <- function(path, session) {
  tryCatch(
    util_read_token_metrics(path),
    error = function(e) {
      logger::log_error("Read failed: {conditionMessage(e)}",
                        namespace = "shokenuse")
      shiny::showNotification(conditionMessage(e), type = "error",
                              session = session)
      util_empty_metrics_tbl()
    }
  )
}


pvt_format_prompts <- function(df) {
  df |>
    dplyr::transmute(
      Time       = format(date, "%Y-%m-%d %H:%M"),
      Project    = project,
      Prompt     = prompt,
      Tokens     = scales::comma(tokens),
      "Cost (USD)" = scales::dollar(cost, accuracy = 0.0001)
    )
}
