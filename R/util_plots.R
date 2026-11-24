.metric_label <- function(metric) {
  if (metric == "cost") "Cost (USD)" else "Tokens"
}

.metric_scale <- function(metric) {
  if (metric == "cost") {
    scales::label_dollar()
  } else {
    scales::label_number(scale_cut = scales::cut_short_scale())
  }
}


#' Daily usage chart
#'
#' Stacked bars of tokens or cost per day, filled by project (top 8 projects,
#' the rest lumped as `"other"`).
#'
#' @param metrics Tibble from [util_read_token_metrics()].
#' @param metric `"tokens"` or `"cost"`.
#' @return A ggplot object.
#' @export
util_plot_daily <- function(metrics, metric = c("tokens", "cost")) {
  metric <- match.arg(metric)
  if (nrow(metrics) == 0) return(.empty_plot("No data in selected range"))

  daily <- metrics |>
    util_lump_projects() |>
    util_summarise_metrics(by = c("day", "project"))

  ggplot2::ggplot(daily, ggplot2::aes(day, .data[[metric]], fill = project)) +
    ggplot2::geom_col() +
    ggplot2::scale_y_continuous(labels = .metric_scale(metric)) +
    ggplot2::scale_x_date(date_labels = "%b %d") +
    ggplot2::labs(x = NULL, y = .metric_label(metric), fill = "Project") +
    ggplot2::theme_minimal(base_size = 13)
}


#' Ranked bar chart
#'
#' Horizontal bars for the top `n` values of a summary column.
#'
#' @param summary Tibble with a label column and a metric column, for example
#'   from [util_summarise_metrics()].
#' @param label Name of the label column.
#' @param metric `"tokens"` or `"cost"`.
#' @param n Number of bars.
#' @return A ggplot object.
#' @export
util_plot_rank <- function(summary, label, metric = c("tokens", "cost"),
                           n = 20) {
  metric <- match.arg(metric)
  if (nrow(summary) == 0) return(.empty_plot())

  top <- dplyr::slice_max(summary, .data[[metric]], n = n, with_ties = FALSE)

  ggplot2::ggplot(top, ggplot2::aes(
    x = .data[[metric]],
    y = stats::reorder(.data[[label]], .data[[metric]])
  )) +
    ggplot2::geom_col(fill = "#2B6C8A") +
    ggplot2::scale_x_continuous(labels = .metric_scale(metric)) +
    ggplot2::labs(x = .metric_label(metric), y = NULL) +
    ggplot2::theme_minimal(base_size = 12)
}


#' Session cost chart
#'
#' Cost of the 30 most expensive sessions, outliers highlighted.
#'
#' @param sessions Tibble from [util_summarise_sessions()].
#' @return A ggplot object.
#' @export
util_plot_sessions <- function(sessions) {
  if (nrow(sessions) == 0) return(.empty_plot())

  top <- sessions |>
    dplyr::slice_head(n = 30) |>
    dplyr::mutate(label = paste0(substr(session, 1, 8), " ", strtrim(project, 30)))

  ggplot2::ggplot(top, ggplot2::aes(
    x = cost, y = stats::reorder(label, cost), fill = outlier
  )) +
    ggplot2::geom_col() +
    ggplot2::scale_fill_manual(
      values = c("FALSE" = "#2B6C8A", "TRUE" = "#E07B39"),
      labels = c("FALSE" = "Normal", "TRUE" = "Outlier (>2 SD)"),
      name   = NULL
    ) +
    ggplot2::scale_x_continuous(labels = scales::label_dollar()) +
    ggplot2::labs(x = "Cost (USD)", y = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "top")
}


#' Prompt size distribution
#'
#' Histogram of tokens or cost per prompt on a log10 scale.
#'
#' @param metrics Tibble from [util_read_token_metrics()].
#' @param metric `"tokens"` or `"cost"`.
#' @return A ggplot object.
#' @export
util_plot_prompts <- function(metrics, metric = c("tokens", "cost")) {
  metric <- match.arg(metric)
  df <- dplyr::filter(metrics, .data[[metric]] > 0)
  if (nrow(df) == 0) return(.empty_plot())

  ggplot2::ggplot(df, ggplot2::aes(.data[[metric]])) +
    ggplot2::geom_histogram(bins = 30, fill = "#2B6C8A", color = "white") +
    ggplot2::scale_x_log10(labels = .metric_scale(metric)) +
    ggplot2::labs(x = paste(.metric_label(metric), "per prompt (log scale)"),
                  y = "Prompts") +
    ggplot2::theme_minimal(base_size = 12)
}


.empty_plot <- function(msg = "No data available") {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg,
                      size = 5, color = "grey50") +
    ggplot2::theme_void()
}
