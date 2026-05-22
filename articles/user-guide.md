# shokenuse User Guide

## Overview

**shokenuse** reads LLM token-usage logs from Claude Code and other AI
assistants, estimates costs using Anthropic’s published pricing, and
surfaces the results in a Shiny dashboard. It is designed for developers
who use Claude Code heavily and want to understand where tokens are
going — across multiple machines, projects, models, and sessions.

The core data pipeline is:

    util_read_claude_code()  ─┐
    util_read_usage_csv()    ─┤─► util_combine_usage() ─► util_add_cost() ─► util_summarise_*()
                              ┘                                                      │
                                                                               launch_app()

------------------------------------------------------------------------

## Installation

Install from the package directory:

``` r

# pak::pak("mjfrigaard/shokenuse")   # once on GitHub
devtools::load_all()                  # during local development
```

------------------------------------------------------------------------

## Reading Claude Code data

Claude Code writes one JSONL file per session under
`~/.claude/projects/`.
[`util_read_claude_code()`](https://mjfrigaard.github.io/shokenuse/reference/util_read_claude_code.md)
scans that directory recursively and returns one row per API response.

``` r

library(shokenuse)

usage <- util_read_claude_code()
usage
```

    # A tibble: 3,847 × 10
       timestamp           machine source       project         session_id  model
       <dttm>              <chr>   <chr>        <chr>           <chr>       <chr>
     1 2026-04-01 08:12:03 local   claude_code  projects/apps/R abc123…     claude-opus-4
     2 2026-04-01 08:12:41 local   claude_code  projects/apps/R abc123…     claude-opus-4
     3 2026-04-01 09:45:10 local   claude_code  projects/pkgs/… def456…     claude-sonnet-4
     # ℹ 3,844 more rows
     # ℹ 4 more variables: input_tokens <int>, cache_creation_tokens <int>,
     #   cache_read_tokens <int>, output_tokens <int>

Each row represents a single assistant response. The four token columns
map directly to Anthropic’s API usage object:

| Column | What it counts |
|----|----|
| `input_tokens` | Prompt tokens that were *not* served from cache |
| `cache_creation_tokens` | Tokens written into the prompt cache (billed at ~1.25× input rate) |
| `cache_read_tokens` | Tokens read *from* the prompt cache (billed at ~10× discount) |
| `output_tokens` | Completion tokens generated |

The `session_id` column is the UUID of the JSONL file; the `project`
column is derived from the folder name Claude Code uses to organise
sessions.

### Reading from a second machine

If you work across two machines, sync or mount the `.claude/projects`
folder from your other machine and pass its path along with a label:

``` r

mac_usage    <- util_read_claude_code("~/.claude/projects",           machine = "macOS")
ubuntu_usage <- util_read_claude_code("/mnt/ubuntu/.claude/projects", machine = "Ubuntu")
usage <- util_combine_usage(mac_usage, ubuntu_usage)
```

[`util_combine_usage()`](https://mjfrigaard.github.io/shokenuse/reference/util_combine_usage.md)
row-binds any number of data frames and sorts the result by timestamp.
The `machine` column lets you filter or facet by machine later.

A convenient way to keep this in one place is to define your directories
once and combine them programmatically:

``` r

my_dirs <- list(
  macOS  = "~/.claude/projects",
  Ubuntu = "/mnt/ubuntu/.claude/projects"
)

usage <- do.call(util_combine_usage, mapply(
  util_read_claude_code, my_dirs, names(my_dirs),
  SIMPLIFY = FALSE
))
```

------------------------------------------------------------------------

## Adding data from other sources

For usage from **Anthropic Console** or **Posit AI assistants** (RStudio
or Positron), export a CSV and load it with
[`util_read_usage_csv()`](https://mjfrigaard.github.io/shokenuse/reference/util_read_usage_csv.md).

### Required CSV columns

| Column          | Type      | Notes                            |
|-----------------|-----------|----------------------------------|
| `timestamp`     | datetime  | Any format `lubridate` can parse |
| `source`        | character | e.g. `"console"`, `"posit_ai"`   |
| `model`         | character | e.g. `"claude-opus-4"`           |
| `input_tokens`  | integer   |                                  |
| `output_tokens` | integer   |                                  |

### Optional CSV columns

| Column                  | Default if absent             | Notes |
|-------------------------|-------------------------------|-------|
| `machine`               | `"manual"` (or `machine` arg) |       |
| `project`               | `NA`                          |       |
| `cache_creation_tokens` | `0`                           |       |
| `cache_read_tokens`     | `0`                           |       |

``` r

console_usage <- util_read_usage_csv(
  "~/Downloads/anthropic_usage_may2026.csv",
  machine = "macOS"
)

all_usage <- util_combine_usage(usage, console_usage)
```

The dashboard’s **Data** tab lets you do the same thing interactively
without writing any code — upload the CSV directly and it merges into
the dashboard.

------------------------------------------------------------------------

## Cost estimation

[`util_add_cost()`](https://mjfrigaard.github.io/shokenuse/reference/util_add_cost.md)
joins each row’s `model` to the built-in pricing table and appends a
`cost_usd` column.

``` r

util_model_pricing()
#> # A tibble: 9 × 5
#>   model             input_pm output_pm cache_write_pm cache_read_pm
#>   <chr>                <dbl>     <dbl>          <dbl>         <dbl>
#> 1 claude-opus-4        15        75             18.8           1.5 
#> 2 claude-sonnet-4       3        15              3.75          0.3 
#> 3 claude-opus-3-5      15        75             18.8           1.5 
#> 4 claude-sonnet-3-7     3        15              3.75          0.3 
#> 5 claude-sonnet-3-5     3        15              3.75          0.3 
#> 6 claude-sonnet-3       3        15              3.75          0.3 
#> 7 claude-haiku-3-5      0.8       4              1             0.08
#> 8 claude-haiku-3        0.25      1.25           0.3           0.03
#> 9 unknown               3        15              3.75          0.3
```

Prices are in USD per million tokens. Cache-read tokens are typically
the largest token category in long Claude Code sessions (the full
project context is re-read on every turn), but they cost roughly **10×
less** than standard input — so the cost impact is often smaller than
the raw counts suggest.

``` r

usage_with_cost <- util_add_cost(usage)
dplyr::select(usage_with_cost, timestamp, model, input_tokens, output_tokens,
              cache_read_tokens, cost_usd)
```

    # A tibble: 3,847 × 6
       timestamp           model           input_tokens output_tokens cache_read_tokens cost_usd
       <dttm>              <chr>                  <int>         <int>             <int>    <dbl>
     1 2026-04-01 08:12:03 claude-opus-4           1284           342             42081   0.0814
     2 2026-04-01 08:12:41 claude-opus-4            891           178             49204   0.0882
     3 2026-04-01 09:45:10 claude-sonnet-4          302            84              8741   0.00365
     # ℹ 3,844 more rows

> **Note:**
> [`util_add_cost()`](https://mjfrigaard.github.io/shokenuse/reference/util_add_cost.md)
> uses estimates based on Anthropic’s published list prices. Actual
> charges on your invoice may differ (e.g. due to volume discounts or
> enterprise agreements). Always treat these figures as *approximate*.

------------------------------------------------------------------------

## Summarising usage

### By date

[`util_summarise_usage()`](https://mjfrigaard.github.io/shokenuse/reference/util_summarise_usage.md)
aggregates token counts and cost by any grouping variable. The default
group is `"date"`:

``` r

daily <- util_summarise_usage(usage_with_cost)
daily
```

    # A tibble: 49 × 7
       date       input_tokens cache_creation_tokens cache_read_tokens output_tokens cost_usd n_requests
       <date>            <int>                 <int>             <int>         <int>    <dbl>      <int>
     1 2026-04-01        48291                182043           2481054        128470     52.4         87
     2 2026-04-02        29183                 91032           1594821         73291     31.8         54
     3 2026-04-03         8102                 22841            441093         21874      9.02        21
     # ℹ 46 more rows

### By model or project

Pass any column name (or a vector of names) to `by`:

``` r

util_summarise_usage(usage_with_cost, by = "model")
util_summarise_usage(usage_with_cost, by = "project")
util_summarise_usage(usage_with_cost, by = c("date", "model"))
```

### Rolling totals

With standard dplyr you can compute cumulative spend over time:

``` r

daily |>
  dplyr::arrange(date) |>
  dplyr::mutate(cumulative_cost = cumsum(cost_usd))
```

------------------------------------------------------------------------

## Exploring sessions

A *session* is one continuous Claude Code conversation (one JSONL file).
Long or exploratory sessions can consume far more tokens than focused
ones.
[`util_summarise_sessions()`](https://mjfrigaard.github.io/shokenuse/reference/util_summarise_sessions.md)
aggregates to one row per session:

``` r

sessions <- util_summarise_sessions(usage_with_cost)
sessions
```

    # A tibble: 214 × 15
       session_id project         machine model           date       duration_min n_requests
       <chr>      <chr>           <chr>   <chr>           <date>            <dbl>      <int>
     1 9f3a1c…    projects/apps/R macOS   claude-opus-4   2026-05-12        187.          43
     2 2d8e4b…    projects/books  macOS   claude-opus-4   2026-05-08         94.2         21
     3 b71f30…    projects/pkgs/… macOS   claude-sonnet-4 2026-05-15         62.4         18
     # ℹ 211 more rows
     # ℹ 8 more variables: input_tokens <int>, output_tokens <int>,
     #   cache_creation_tokens <int>, cache_read_tokens <int>,
     #   total_tokens <int>, cost_usd <dbl>, outlier <lgl>

### The `outlier` flag

Sessions whose estimated cost exceeds **mean + 2 standard deviations**
across all sessions are flagged `outlier = TRUE`. These are worth
inspecting — they often correspond to a very long back-and-forth on a
tricky problem, or to accidental re-processing of a large file.

``` r

sessions |>
  dplyr::filter(outlier) |>
  dplyr::select(session_id, project, date, n_requests, cost_usd)
```

When only one session exists, or when all sessions cost the same
(standard deviation is zero), `outlier` is `FALSE` for every row rather
than `NA`.

### Synthetic example (runs without local data)

``` r

# Build a usage history: many cheap sonnet-4 sessions + one expensive opus-4 session.
# We pre-set cost_usd directly to keep the example independent of pricing changes.
make_session_row <- function(sid, model, cost) {
  tibble::tibble(
    timestamp             = as.POSIXct("2026-05-01", tz = "UTC"),
    machine               = "macOS",
    source                = "claude_code",
    project               = "projects/demo",
    session_id            = sid,
    model                 = model,
    input_tokens          = 500L,
    cache_creation_tokens = 0L,
    cache_read_tokens     = 1000L,
    output_tokens         = 100L,
    cost_usd              = cost
  )
}

synthetic <- dplyr::bind_rows(
  mapply(
    \(i) make_session_row(paste0("cheap-", i), "claude-sonnet-4", 0.01),
    seq_len(9), SIMPLIFY = FALSE
  ),
  list(make_session_row("expensive-1", "claude-opus-4", 8.50))
)

util_summarise_sessions(synthetic) |>
  dplyr::select(session_id, models, n_requests, total_tokens, cost_usd, outlier)
#> INFO [2026-05-22 16:12:08] Summarising 10 row(s) into sessions
#> INFO [2026-05-22 16:12:08] Sessions: 10 total, 1 outlier(s)
#> # A tibble: 10 × 6
#>    session_id  models          n_requests total_tokens cost_usd outlier
#>    <chr>       <chr>                <int>        <int>    <dbl> <lgl>  
#>  1 expensive-1 claude-opus-4            1         1600     8.5  TRUE   
#>  2 cheap-1     claude-sonnet-4          1         1600     0.01 FALSE  
#>  3 cheap-2     claude-sonnet-4          1         1600     0.01 FALSE  
#>  4 cheap-3     claude-sonnet-4          1         1600     0.01 FALSE  
#>  5 cheap-4     claude-sonnet-4          1         1600     0.01 FALSE  
#>  6 cheap-5     claude-sonnet-4          1         1600     0.01 FALSE  
#>  7 cheap-6     claude-sonnet-4          1         1600     0.01 FALSE  
#>  8 cheap-7     claude-sonnet-4          1         1600     0.01 FALSE  
#>  9 cheap-8     claude-sonnet-4          1         1600     0.01 FALSE  
#> 10 cheap-9     claude-sonnet-4          1         1600     0.01 FALSE
```

------------------------------------------------------------------------

## Launching the dashboard

[`launch_app()`](https://mjfrigaard.github.io/shokenuse/reference/launch_app.md)
opens the Shiny dashboard. The app starts empty — load data from the
**Data** tab using an Admin API key or by uploading a CSV.

``` r

launch_app()
```

### Dashboard tabs

| Tab | What it shows |
|----|----|
| **Data** | Load data via Admin API key or CSV upload; download local conversion scripts |
| **Overview** | Daily token volume (stacked bar), five key metric boxes, date / machine / source filters |
| **By Model** | Token volume and cost broken out by Claude model; usage trends over time |
| **By Project** | Top 20 projects by total tokens and estimated cost |
| **Sessions** | Per-session cost and token charts with outlier highlighting; detail table with CSV export |
| **Pricing** | Current pricing table with a link to Anthropic’s live pricing page |

------------------------------------------------------------------------

## Keeping pricing current

Anthropic updates model pricing periodically.
[`util_model_pricing()`](https://mjfrigaard.github.io/shokenuse/reference/util_model_pricing.md)
returns the table that
[`util_add_cost()`](https://mjfrigaard.github.io/shokenuse/reference/util_add_cost.md)
uses; you can inspect it at any time:

``` r

util_model_pricing()
#> # A tibble: 9 × 5
#>   model             input_pm output_pm cache_write_pm cache_read_pm
#>   <chr>                <dbl>     <dbl>          <dbl>         <dbl>
#> 1 claude-opus-4        15        75             18.8           1.5 
#> 2 claude-sonnet-4       3        15              3.75          0.3 
#> 3 claude-opus-3-5      15        75             18.8           1.5 
#> 4 claude-sonnet-3-7     3        15              3.75          0.3 
#> 5 claude-sonnet-3-5     3        15              3.75          0.3 
#> 6 claude-sonnet-3       3        15              3.75          0.3 
#> 7 claude-haiku-3-5      0.8       4              1             0.08
#> 8 claude-haiku-3        0.25      1.25           0.3           0.03
#> 9 unknown               3        15              3.75          0.3
```

When prices change, update the
[`tibble::tribble()`](https://tibble.tidyverse.org/reference/tribble.html)
call in `R/util_data.R` and re-install the package. The `"unknown"` row
acts as a fallback for any model name not yet in the table, using
sonnet-4 prices.

------------------------------------------------------------------------

## Typical workflow

``` r

library(shokenuse)

# 1. Parse local Claude Code logs
usage <- util_read_claude_code("~/.claude/projects", machine = "macOS")

# 2. Optionally add Console exports
usage <- util_combine_usage(
  usage,
  util_read_usage_csv("~/Downloads/console_export.csv", machine = "macOS")
)

# 3. Compute costs
usage <- util_add_cost(usage)

# 4. Quick summaries in the console
util_summarise_usage(usage, by = "model")
util_summarise_usage(usage, by = c("date", "source"))

# 5. Find expensive sessions
util_summarise_sessions(usage) |> dplyr::filter(outlier)

# 6. Explore interactively — load additional data from the Data tab
launch_app()
```
