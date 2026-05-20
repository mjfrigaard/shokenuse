#' Primary application UI
#'
#' Assembles the top-level `bslib::page_navbar` from all module UIs.
#'
#' @return A Shiny UI definition.
#' @export
app_ui <- function() {
  bslib::page_navbar(
    title = shiny::tags$span(
      bsicons::bs_icon("cpu"), " shokenuse"
    ),
    theme = bslib::bs_theme(
      version    = 5,
      bootswatch = "flatly",
      primary    = "#6C63FF"
    ),
    window_title = "shokenuse — LLM Token Usage",

    bslib::nav_panel(
      "Overview",
      icon = bsicons::bs_icon("bar-chart-line"),
      mod_overview_ui("overview")
    ),
    bslib::nav_panel(
      "By Model",
      icon = bsicons::bs_icon("diagram-3"),
      mod_model_ui("model")
    ),
    bslib::nav_panel(
      "By Project",
      icon = bsicons::bs_icon("folder"),
      mod_project_ui("project")
    ),
    bslib::nav_panel(
      "Sessions",
      icon = bsicons::bs_icon("chat-text"),
      mod_sessions_ui("sessions")
    ),
    bslib::nav_panel(
      "Upload Data",
      icon = bsicons::bs_icon("cloud-upload"),
      mod_upload_ui("upload")
    ),
    bslib::nav_panel(
      "Pricing",
      icon = bsicons::bs_icon("table"),
      mod_pricing_ui("pricing")
    ),
    bslib::nav_panel(
      "API Data",
      icon = bsicons::bs_icon("cloud-download"),
      mod_api_ui("api")
    ),

    bslib::nav_spacer(),
    bslib::nav_item(
      shiny::actionButton(
        "refresh_btn",
        label = NULL,
        icon  = shiny::icon("rotate"),
        class = "btn-sm btn-outline-secondary",
        title = "Reload data from disk"
      )
    )
  )
}
