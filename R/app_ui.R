#' Primary application UI
#'
#' @param dir Default token-metrics folder shown on the Data tab.
#' @return A Shiny UI definition.
#' @export
app_ui <- function(dir = util_metrics_dir()) {
  bslib::page_navbar(
    title = shiny::tags$span(bsicons::bs_icon("cpu"), " shokenuse"),
    theme = bslib::bs_theme(
      version    = 5,
      bootswatch = "flatly",
      primary    = "#2B6C8A",   # blueprint blue
      secondary  = "#7D9AB5",   # steel blue-grey
      success    = "#3D9E8F",   # atomic teal
      info       = "#5DABC8",   # sky blue
      warning    = "#E07B39",   # burnt orange
      danger     = "#C84B2E",   # brick red
      "body-bg"  = "#F8F4EE",   # warm cream
      "navbar-bg" = "#1D3A4A"   # deep navy
    ),
    window_title = "shokenuse: Claude Code token usage",
    fillable = FALSE,
    sidebar = mod_filters_ui("filters"),

    bslib::nav_panel("Data", icon = bsicons::bs_icon("database"),
                     mod_data_ui("data", dir = dir)),
    bslib::nav_panel("Overview", icon = bsicons::bs_icon("bar-chart-line"),
                     mod_overview_ui("overview")),
    bslib::nav_panel("By Project", icon = bsicons::bs_icon("folder"),
                     mod_project_ui("project")),
    bslib::nav_panel("Sessions", icon = bsicons::bs_icon("collection"),
                     mod_sessions_ui("sessions")),
    bslib::nav_panel("Prompts", icon = bsicons::bs_icon("chat-left-text"),
                     mod_prompts_ui("prompts")),
    bslib::nav_spacer()
  )
}
