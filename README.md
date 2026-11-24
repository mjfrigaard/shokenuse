

<!-- README.md is generated from README.qmd. Please edit that file -->

# shokenuse

shokenuse is a Shiny dashboard for Claude Code token use and cost. It
reads the daily CSV files written by `token-metrics.py`, where each row
is one prompt.

## Installation

``` r
# pak::pak("mjfrigaard/shokenuse")
devtools::load_all()
```

## Quick start

`launch_app()` reads `~/.cache/token-metrics` by default. The package
also ships a week of example data:

``` r
library(shokenuse)
launch_app()   # reads ~/.cache/token-metrics

# Example data shipped with the package
launch_app(dir = system.file("extdata", "token-metrics", package = "shokenuse"))
```

## The data

`token-metrics.py` reads Claude Code’s transcripts in
`~/.claude/projects/` (subagents included) and writes
`~/.cache/token-metrics/YYYY-MM-DD-token-metrics.csv` every hour. Each
row is one prompt:

| Column | Meaning |
|----|----|
| `date` | Local time the prompt was sent |
| `session` | Session id (`claude --resume <id>`) |
| `project` | Git repository name of the working directory (else the folder name) |
| `directory` | Working directory |
| `url` | Git remote `origin` (blank if none) |
| `prompt` | First 140 characters |
| `tokens` | Input, output, cache write, and cache read tokens for every call answering the prompt |
| `cost` | USD at API list prices (blank if a model has no price) |

See `vignette("token-metrics")` for how the script finds prompts, prices
calls, and assigns them to prompts.

## Architecture

The first diagram shows how the data reaches the app. The second shows
how the modules inside the app share it. The Data module reads the files
and the Filters module applies the sidebar filters. Each tab then
receives the filtered data.

``` mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'fontFamily': 'monospace', 'fontSize':'16px', 'darkMode':false}}}%%

flowchart TD
    cc(["<strong>Claude Code</strong>"]) --> tr[("transcripts<br/><code>~/.claude/projects/</code>")]
    tr --> py("<code>token-metrics.py</code><br/>hourly")
    py --> csv[("daily CSVs<br/><code>~/.cache/token-metrics/</code>")]
    csv --> rd[["<code>util_read_token_metrics()</code>"]]
    rd --> app(["<strong>shokenuse</strong><br/>Overview, By Project, Sessions, Prompts"])

    style py fill:#4CBB9D,color:#FFFFFF,rx:5,ry:5
    style rd fill:#4CBB9D,color:#FFFFFF
```

``` mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'fontFamily': 'monospace', 'fontSize':'16px', 'darkMode':false}}}%%

flowchart TD
    launch(["<code>launch_app(dir)</code>"]) --> ui[["<code>app_ui()</code><br/>navbar, filters sidebar, tab UIs"]]
    launch --> data
    csv[("token-metrics folder")] --> data
    up[/"uploaded CSVs"/] --> data
    subgraph srv["<strong>app_server()</strong>"]
        data[["<code>mod_data_server()</code><br/>util_read_token_metrics()"]]
        filt[["<code>mod_filters_server()</code><br/>date range, projects"]]
        ov[["<code>mod_overview_server()</code><br/>util_plot_daily()"]]
        pr[["<code>mod_project_server()</code><br/>util_plot_rank()"]]
        se[["<code>mod_sessions_server()</code><br/>util_summarise_sessions()"]]
        po[["<code>mod_prompts_server()</code><br/>util_plot_prompts()"]]
        data -->|"metrics"| filt
        filt -->|"filtered"| ov
        filt -->|"filtered"| pr
        filt -->|"filtered"| se
        filt -->|"filtered"| po
    end

    style srv fill:#FFFFFF,color:#000000,stroke:#333,stroke-width:1px,rx:10,ry:10
    style data fill:#4CBB9D,color:#FFFFFF
    style filt fill:#4CBB9D,color:#FFFFFF
```

## Dashboard tabs

The sidebar filters (date range and projects) apply to every tab after
Data.

| Tab        | Description                                         |
|------------|-----------------------------------------------------|
| Data       | Folder path, reload, and CSV upload; latest prompts |
| Overview   | Totals and daily tokens or cost by project          |
| By Project | Tokens and cost per project, with git remotes       |
| Sessions   | One row per session, outliers flagged, CSV export   |
| Prompts    | Search and rank prompts by tokens or cost           |

## Utility functions

The functions behind the tabs are exported, so you can run the same
summaries without the app:

``` r
metrics <- util_read_token_metrics()

util_summarise_metrics(metrics, by = "day")
util_summarise_metrics(metrics, by = c("day", "project"))
util_summarise_sessions(metrics)
util_plot_daily(metrics, "cost")
```

## Changing the log level

shokenuse logs with the `logger` package. `util_log_threshold()` sets
how much it logs:

``` r
util_log_threshold("DEBUG")  # "INFO" | "WARN" | "ERROR" | "DEBUG" | "OFF"
launch_app()
```
