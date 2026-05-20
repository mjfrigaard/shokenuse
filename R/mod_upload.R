#' Upload Data tab module UI
#'
#' @param id Shiny module ID.
#' @export
mod_upload_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_columns(
    col_widths = c(4, 8),
    bslib::card(
      bslib::card_header("Upload CSV"),
      shiny::p(
        "Export usage from the Anthropic Console or your Posit AI assistant",
        "and upload a CSV here. Required columns:",
        shiny::tags$code("timestamp, source, model, input_tokens, output_tokens")
      ),
      shiny::p(
        "Optional: ",
        shiny::tags$code("machine, project, cache_creation_tokens, cache_read_tokens")
      ),
      shiny::fileInput(
        ns("csv_upload"), "Choose CSV file",
        accept      = ".csv",
        buttonLabel = "Browse…"
      ),
      shiny::textInput(ns("upload_machine"), "Machine label", value = "manual"),
      shiny::downloadButton(
        ns("dl_template"), "Download template CSV",
        class = "btn-sm btn-outline-primary"
      )
    ),
    bslib::card(
      full_screen = TRUE,
      bslib::card_header("Uploaded Data Preview"),
      shiny::tableOutput(ns("upload_preview"))
    )
  )
}


#' Upload Data tab module server
#'
#' @param id Shiny module ID.
#' @param raw_usage_rv `reactiveVal` holding the full usage tibble. Uploaded
#'   data is merged into this value.
#' @export
mod_upload_server <- function(id, raw_usage_rv) {
  shiny::moduleServer(id, function(input, output, session) {
    logger::log_debug("mod_upload initialised", namespace = "shokenuse")

    shiny::observeEvent(input$csv_upload, {
      shiny::req(input$csv_upload)
      logger::log_info(
        "CSV upload received: {input$csv_upload$name}",
        namespace = "shokenuse"
      )
      tryCatch(
        {
          new_data <- util_read_usage_csv(
            input$csv_upload$datapath,
            machine = input$upload_machine
          )
          new_data <- util_add_cost(new_data)
          new_data <- dplyr::mutate(new_data, date = as.Date(timestamp))
          combined <- util_combine_usage(raw_usage_rv(), new_data)
          raw_usage_rv(combined)
          logger::log_info(
            "CSV merged: {nrow(new_data)} new row(s) added",
            namespace = "shokenuse"
          )
          shiny::showNotification("CSV data merged successfully.", type = "message")
        },
        error = function(e) {
          logger::log_error(
            "CSV upload failed: {conditionMessage(e)}",
            namespace = "shokenuse"
          )
          shiny::showNotification(
            paste("Error reading CSV:", conditionMessage(e)),
            type = "error"
          )
        }
      )
    })

    output$upload_preview <- shiny::renderTable({
      df <- raw_usage_rv()
      uploaded <- dplyr::filter(df, source != "claude_code")
      if (nrow(uploaded) == 0) return(data.frame(Status = "No uploaded data yet."))
      utils::head(uploaded, 50)
    })

    output$dl_template <- shiny::downloadHandler(
      filename = "shokenuse_template.csv",
      content  = function(file) {
        template <- data.frame(
          timestamp             = as.character(Sys.time()),
          source                = "console",
          machine               = "macOS",
          model                 = "claude-opus-4",
          project               = "my-project",
          input_tokens          = 1000L,
          output_tokens         = 500L,
          cache_creation_tokens = 0L,
          cache_read_tokens     = 0L
        )
        utils::write.csv(template, file, row.names = FALSE)
      }
    )
  })
}
