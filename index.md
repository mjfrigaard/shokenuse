# shokenuse

A Shiny dashboard for tracking Anthropic API token usage and estimated
costs across models, projects, and sessions.

## Installation

``` r

# During local development
devtools::load_all()

# Install from GitHub (once published)
# pak::pak("mjfrigaard/shokenuse")
```

## Quick start

``` r

library(shokenuse)
launch_app()
```

The dashboard opens to the **Data** tab. Load data in one of two ways:

**1. Admin API key** — fetches the last 30 days from your Anthropic
organization account.  
Enter your `sk-ant-admin...` key, give the source a Machine label
(e.g. `"org-name"`), click **Fetch Usage**, then **Add to Dashboard**.
Repeat with a different key to load data from another organization.

**2. Upload CSV** — paste in a usage export from the Anthropic Console
or another tool.  
Download an R or shell conversion script from the Data tab to export
your local `~/.claude/projects/` session logs first.

## Dashboard tabs

| Tab | Description |
|----|----|
| **Data** | Load data via Admin API key or CSV upload; download local conversion scripts |
| **Overview** | Daily token volume (stacked bar), five metric value boxes, date / machine / source filters |
| **By Model** | Token volume and cost by Claude model; usage trends over time |
| **By Project** | Top 20 projects by total tokens and estimated cost |
| **Sessions** | Per-session cost and token breakdown with outlier highlighting; CSV export |
| **Pricing** | Per-model pricing table used for cost estimates; link to Anthropic’s live rates |

## Utility functions

The `util_*` functions work independently of the dashboard for scripted
analysis:

``` r

# Read local Claude Code session logs
usage <- util_read_claude_code("~/.claude/projects", machine = "macOS")

# Parse a CSV export
csv   <- util_read_usage_csv("export.csv", machine = "macOS")

# Combine multiple sources
all   <- util_combine_usage(usage, csv)

# Add cost estimates
all   <- util_add_cost(all)

# Summarise by any column
util_summarise_usage(all, by = "model")
util_summarise_usage(all, by = c("date", "source"))

# Session-level breakdown with outlier flags
util_summarise_sessions(all)
```

## Fetch from the Admin API directly

``` r

# Reads ANTHROPIC_ADMIN_KEY from the environment
usage <- util_fetch_usage(
  starting_at  = "2025-01-01T00:00:00Z",
  ending_at    = "2025-01-31T23:59:59Z",
  bucket_width = "1d",
  group_by     = "model"
)
```

See
[`vignette("api-usage")`](https://mjfrigaard.github.io/shokenuse/articles/api-usage.md)
for the full Admin API reference.

## Logging

``` r

util_log_threshold("DEBUG")  # "INFO" | "WARN" | "ERROR" | "DEBUG"
launch_app()
```
