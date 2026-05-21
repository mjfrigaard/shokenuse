#' Data tab module UI (landing page)
#'
#' Primary entry point for loading usage data. Supports fetching via the
#' Anthropic Admin API (primary) or uploading a CSV file (alternative).
#' Also provides downloadable scripts to convert local Claude Code session
#' logs into the expected CSV format.
#'
#' @param id Shiny module ID.
#' @export
mod_data_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_columns(
    col_widths = c(4, 8),
    bslib::card(
      bslib::card_header("Load Data"),

      shiny::h6("Fetch from Anthropic Admin API"),
      shiny::p(
        class = "text-muted small",
        shiny::tags$strong("Requires an Admin API key"),
        " (", shiny::tags$code("sk-ant-admin..."), ") from an",
        shiny::tags$em("organization"), " account — not available for",
        "individual accounts."
      ),
      shiny::passwordInput(
        ns("admin_key"), "Admin API Key",
        placeholder = "sk-ant-admin..."
      ),
      shiny::textInput(
        ns("api_machine"), "Machine label",
        value       = "api",
        placeholder = "e.g. org-name"
      ),
      shiny::actionButton(
        ns("fetch_btn"), "Fetch Usage",
        class = "btn-primary w-100"
      ),
      shiny::uiOutput(ns("merge_ui")),
      shiny::p(
        class = "text-muted small mt-2 mb-0",
        bsicons::bs_icon("info-circle"),
        " Each fetch adds to the dashboard — change the Machine label and",
        "enter a different key to load data from another organization."
      ),

      shiny::div(
        class = "d-flex align-items-center my-3",
        shiny::hr(style = "flex: 1;"),
        shiny::span(class = "mx-2 text-muted small fw-semibold", "or"),
        shiny::hr(style = "flex: 1;")
      ),

      shiny::h6("Upload CSV"),
      shiny::p(
        class = "text-muted small mb-1",
        "Required columns: ",
        shiny::tags$code("timestamp"), ", ",
        shiny::tags$code("source"), ", ",
        shiny::tags$code("model"), ", ",
        shiny::tags$code("input_tokens"), ", ",
        shiny::tags$code("output_tokens")
      ),
      shiny::br(),
      shiny::p(
        class = "text-muted small",
        "Optional: ",
        shiny::tags$code("machine"), ", ",
        shiny::tags$code("project"), ", ",
        shiny::tags$code("cache_creation_tokens"), ", ",
        shiny::tags$code("cache_read_tokens")
      ),
      shiny::fileInput(
        ns("csv_upload"), NULL,
        accept      = ".csv",
        buttonLabel = "Browse…"
      ),
      shiny::textInput(ns("upload_machine"), "Machine label", value = "manual"),

      shiny::hr(),

      shiny::h6("Convert local Claude Code data"),
      shiny::p(
        class = "text-muted small",
        "Download a script to export your",
        shiny::tags$code("~/.claude/projects/"),
        "session logs as CSV, then upload the result above."
      ),
      shiny::div(
        class = "d-flex gap-2",
        shiny::downloadButton(
          ns("dl_r_script"), "R script",
          class = "btn-sm btn-outline-primary flex-fill"
        ),
        bslib::tooltip(
          trigger = shiny::downloadButton(
            ns("dl_sh_script"),
            shiny::tagList("Shell script ", bsicons::bs_icon("info-circle", size = "0.8em")),
            class = "btn-sm btn-outline-primary flex-fill"
          ),
          "Requires jq — install with: brew install jq (macOS) or sudo apt install jq (Linux)",
          placement = "top"
        ),
        shiny::downloadButton(
          ns("dl_template"), "CSV template",
          class = "btn-sm btn-outline-secondary flex-fill"
        )
      )
    ),

    bslib::card(
      bslib::card_header("Data Preview"),
      shiny::uiOutput(ns("data_status")),
      shiny::div(
        style = "min-width: 300px; overflow: hidden;",
        shiny::plotOutput(ns("plot_preview"), height = "280px", width = "100%")
      ),
      shiny::div(
        style = "overflow-x: auto;",
        shiny::tableOutput(ns("tbl_preview"))
      )
    )
  )
}


#' Data tab module server
#'
#' @param id Shiny module ID.
#' @param raw_usage_rv `reactiveVal` holding the full usage tibble.
#' @export
mod_data_server <- function(id, raw_usage_rv) {
  shiny::moduleServer(id, function(input, output, session) {
    logger::log_debug("mod_data initialised", namespace = "shokenuse")

    api_data <- shiny::reactiveVal(NULL)

    shiny::observeEvent(input$fetch_btn, {
      shiny::req(nzchar(input$admin_key))
      start <- paste0(Sys.Date() - 30, "T00:00:00Z")
      end   <- paste0(Sys.Date(),      "T23:59:59Z")
      logger::log_info(
        "Admin API fetch: {start} to {end}",
        namespace = "shokenuse"
      )
      result <- tryCatch(
        util_fetch_usage(
          starting_at  = start,
          ending_at    = end,
          bucket_width = "1d",
          group_by     = "model",
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

    output$merge_ui <- shiny::renderUI({
      d <- api_data()
      if (is.null(d)) return(NULL)
      shiny::div(
        class = "mt-2",
        shiny::actionButton(
          session$ns("merge_btn"), "Add to Dashboard",
          class = "btn-outline-success btn-sm w-100"
        )
      )
    })

    shiny::observeEvent(input$merge_btn, {
      d <- api_data()
      shiny::req(!is.null(d))
      if (!"model" %in% names(d)) d$model <- "unknown"

      machine_label <- if (nzchar(trimws(input$api_machine))) trimws(input$api_machine) else "api"

      new_rows <- tibble::tibble(
        timestamp             = as.POSIXct(d$timestamp_bucket, tz = "UTC"),
        machine               = machine_label,
        source                = "anthropic_api",
        project               = NA_character_,
        session_id            = NA_character_,
        model                 = d$model,
        input_tokens          = as.integer(d$input_tokens                    %||% 0L),
        cache_creation_tokens = as.integer(d$cache_creation_input_tokens     %||% 0L),
        cache_read_tokens     = as.integer(d$cache_read_input_tokens         %||% 0L),
        output_tokens         = as.integer(d$output_tokens                   %||% 0L)
      )
      new_rows <- util_add_cost(new_rows)
      new_rows <- dplyr::mutate(new_rows, date = as.Date(timestamp))
      combined <- util_combine_usage(raw_usage_rv(), new_rows)
      raw_usage_rv(combined)
      api_data(NULL)
      shiny::showNotification("API data added to dashboard.", type = "message")
    })

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
            "CSV merged: {nrow(new_data)} row(s) added",
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

    output$data_status <- shiny::renderUI({
      d_api <- api_data()
      df    <- raw_usage_rv()

      if (!is.null(d_api)) {
        return(shiny::p(
          class = "text-success small mb-1",
          paste("API fetch returned", nrow(d_api),
                "records — click 'Add to Dashboard' to include them.")
        ))
      }
      if (nrow(df) == 0) {
        return(shiny::p(
          class = "text-muted small",
          "No data loaded. Fetch from the API or upload a CSV to get started."
        ))
      }
      shiny::p(
        class = "text-muted small mb-1",
        paste("Dashboard contains", scales::comma(nrow(df)), "rows across",
              length(unique(df$source)), "source(s).")
      )
    })

    output$plot_preview <- shiny::renderPlot({
      d_api <- api_data()
      if (!is.null(d_api) && nrow(d_api) > 0) {
        fill_col <- if ("model" %in% names(d_api)) "model" else NULL
        d_api$ts <- as.POSIXct(d_api$timestamp_bucket)
        p <- ggplot2::ggplot(d_api, ggplot2::aes(x = ts, y = input_tokens))
        if (!is.null(fill_col)) p <- p + ggplot2::aes(fill = .data[[fill_col]])
        return(
          p +
            ggplot2::geom_col() +
            ggplot2::scale_y_continuous(
              labels = scales::label_number(scale_cut = scales::cut_short_scale())
            ) +
            ggplot2::labs(x = NULL, y = "Input tokens", fill = "Model") +
            ggplot2::theme_minimal(base_size = 12) +
            ggplot2::theme(
              legend.position = "bottom",
              plot.margin     = ggplot2::margin(2, 2, 2, 2)
            )
        )
      }

      df <- raw_usage_rv()
      if (nrow(df) == 0) return(.empty_plot("Load data to see preview"))

      daily <- df |>
        dplyr::group_by(date, source) |>
        dplyr::summarise(
          tokens = sum(input_tokens + output_tokens, na.rm = TRUE),
          .groups = "drop"
        )
      ggplot2::ggplot(daily, ggplot2::aes(x = date, y = tokens, fill = source)) +
        ggplot2::geom_col() +
        ggplot2::scale_y_continuous(
          labels = scales::label_number(scale_cut = scales::cut_short_scale())
        ) +
        ggplot2::labs(x = NULL, y = "Tokens (in + out)", fill = "Source") +
        ggplot2::theme_minimal(base_size = 12) +
        ggplot2::theme(
          legend.position = "bottom",
          plot.margin     = ggplot2::margin(2, 2, 2, 2)
        )
    }, res = 96)

    output$tbl_preview <- shiny::renderTable({
      d_api <- api_data()
      if (!is.null(d_api)) return(utils::head(d_api, 20))

      df <- raw_usage_rv()
      if (nrow(df) == 0) return(data.frame(Status = "No data loaded yet."))
      utils::head(df, 20)
    })

    output$dl_r_script <- shiny::downloadHandler(
      filename = "convert_claude_to_csv.R",
      content  = function(file) {
        script <- paste0(
          '# convert_claude_to_csv.R\n',
          '# Reads Claude Code local JSONL session logs and exports them as CSV.\n',
          '# Requires: jsonlite (install.packages("jsonlite"))\n',
          '# Usage:    Rscript convert_claude_to_csv.R\n\n',
          '`%||%` <- function(x, y) if (is.null(x)) y else x\n\n',
          'parse_jsonl_file <- function(path) {\n',
          '  lines <- readLines(path, warn = FALSE)\n',
          '  lines <- lines[nzchar(trimws(lines))]\n',
          '  if (length(lines) == 0L) return(NULL)\n',
          '  rows <- lapply(lines, function(l) {\n',
          '    r <- tryCatch(jsonlite::fromJSON(l, simplifyDataFrame = FALSE),\n',
          '                  error = function(e) NULL)\n',
          '    if (is.null(r)) return(NULL)\n',
          '    msg   <- r[["message"]]\n',
          '    usage <- if (!is.null(msg)) msg[["usage"]] else NULL\n',
          '    if (is.null(usage)) return(NULL)\n',
          '    data.frame(\n',
          '      timestamp             = r[["timestamp"]]                           %||% NA_character_,\n',
          '      session_id            = r[["sessionId"]]                           %||% NA_character_,\n',
          '      model                 = msg[["model"]]                             %||% NA_character_,\n',
          '      input_tokens          = as.integer(usage[["input_tokens"]]                %||% 0L),\n',
          '      cache_creation_tokens = as.integer(usage[["cache_creation_input_tokens"]] %||% 0L),\n',
          '      cache_read_tokens     = as.integer(usage[["cache_read_input_tokens"]]     %||% 0L),\n',
          '      output_tokens         = as.integer(usage[["output_tokens"]]               %||% 0L),\n',
          '      stringsAsFactors = FALSE\n',
          '    )\n',
          '  })\n',
          '  do.call(rbind, Filter(Negate(is.null), rows))\n',
          '}\n\n',
          'if (!requireNamespace("jsonlite", quietly = TRUE))\n',
          '  stop("Please install jsonlite: install.packages(\'jsonlite\')")\n\n',
          'claude_dir <- path.expand("~/.claude/projects")\n',
          'if (!dir.exists(claude_dir)) stop("Directory not found: ", claude_dir)\n\n',
          'files <- list.files(claude_dir, pattern = "\\\\.jsonl$",\n',
          '                    recursive = TRUE, full.names = TRUE)\n',
          'cat("Found", length(files), "JSONL file(s)\\n")\n',
          'if (length(files) == 0L) stop("No JSONL files found.")\n\n',
          'all_data <- do.call(rbind, lapply(files, parse_jsonl_file))\n',
          'if (is.null(all_data) || nrow(all_data) == 0L)\n',
          '  stop("No usage records found.")\n\n',
          'all_data$source  <- "claude_code"\n',
          'all_data$machine <- Sys.info()[["nodename"]]\n\n',
          'out_file <- paste0("claude_usage_", Sys.Date(), ".csv")\n',
          'write.csv(all_data, out_file, row.names = FALSE)\n',
          'cat("Exported", nrow(all_data), "rows to", out_file, "\\n")\n'
        )
        writeLines(script, file)
      }
    )

    output$dl_sh_script <- shiny::downloadHandler(
      filename = "convert_claude_to_csv.sh",
      content  = function(file) {
        script <- paste0(
          '#!/usr/bin/env bash\n',
          '# convert_claude_to_csv.sh\n',
          '# Exports Claude Code local session logs (~/.claude/projects/) to CSV.\n',
          '# Requires: jq  (macOS: brew install jq | Linux: apt install jq)\n',
          '# Usage:    bash convert_claude_to_csv.sh\n',
          '# Output:   claude_usage_YYYY-MM-DD.csv in the current directory\n\n',
          'set -euo pipefail\n\n',
          'CLAUDE_DIR="${HOME}/.claude/projects"\n',
          'OUT_FILE="claude_usage_$(date +%F).csv"\n',
          'MACHINE=$(hostname)\n',
          'ROW_COUNT=0\n\n',
          'if ! command -v jq &>/dev/null; then\n',
          '  echo "Error: jq is required." >&2\n',
          '  echo "  macOS:  brew install jq" >&2\n',
          '  echo "  Linux:  sudo apt install jq" >&2\n',
          '  exit 1\n',
          'fi\n\n',
          'if [ ! -d "$CLAUDE_DIR" ]; then\n',
          '  echo "Error: directory not found: $CLAUDE_DIR" >&2\n',
          '  exit 1\n',
          'fi\n\n',
          'echo "timestamp,session_id,model,input_tokens,cache_creation_tokens,cache_read_tokens,output_tokens,source,machine" > "$OUT_FILE"\n\n',
          'while IFS= read -r -d \'\' JSONL_FILE; do\n',
          '  while IFS= read -r line || [ -n "$line" ]; do\n',
          '    [ -z "$line" ] && continue\n',
          '    row=$(printf \'%s\' "$line" | jq -r \'\n',
          '      select(.message.usage != null) |\n',
          '      [\n',
          '        (.timestamp // ""),\n',
          '        (.sessionId // ""),\n',
          '        (.message.model // ""),\n',
          '        (.message.usage.input_tokens // 0),\n',
          '        (.message.usage.cache_creation_input_tokens // 0),\n',
          '        (.message.usage.cache_read_input_tokens // 0),\n',
          '        (.message.usage.output_tokens // 0),\n',
          '        "claude_code",\n',
          '        "\'\"$MACHINE\"\'" \n',
          '      ] | @csv\n',
          '    \' 2>/dev/null) || continue\n',
          '    [ -z "$row" ] && continue\n',
          '    printf \'%s\\n\' "$row" >> "$OUT_FILE"\n',
          '    ROW_COUNT=$((ROW_COUNT + 1))\n',
          '  done < "$JSONL_FILE"\n',
          'done < <(find "$CLAUDE_DIR" -name "*.jsonl" -type f -print0)\n\n',
          'echo "Exported $ROW_COUNT row(s) to $OUT_FILE"\n'
        )
        writeLines(script, file)
      }
    )

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
