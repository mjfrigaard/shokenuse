# Using the Anthropic Admin API

## Overview

The **Admin API** utilities in shokenuse
([`util_fetch_usage()`](https://mjfrigaard.github.io/shokenuse/reference/util_fetch_usage.md)
and
[`util_fetch_cost()`](https://mjfrigaard.github.io/shokenuse/reference/util_fetch_cost.md))
provide programmatic access to your organization’s historical token
usage and cost data from Anthropic’s reporting endpoints.

> **Important:** These functions require an **Admin API key**
> (`sk-ant-admin...`) provisioned through the Anthropic Console. They
> are **not available for individual (personal) accounts** — only for
> organizations with the Admin API enabled.

------------------------------------------------------------------------

## Prerequisites

### 1. Get an Admin API key

In the [Anthropic Console](https://console.anthropic.com), navigate to
**Settings → Admin Keys** and create a key. Store it as an environment
variable:

``` bash
export ANTHROPIC_ADMIN_KEY="sk-ant-admin..."
```

Or add it to your `~/.Renviron`:

    ANTHROPIC_ADMIN_KEY=sk-ant-admin...

### 2. Verify the key is available in R

``` r

nzchar(Sys.getenv("ANTHROPIC_ADMIN_KEY"))
```

------------------------------------------------------------------------

## Fetching usage data

[`util_fetch_usage()`](https://mjfrigaard.github.io/shokenuse/reference/util_fetch_usage.md)
wraps the `GET /v1/organizations/usage_report/messages` endpoint. It
handles pagination automatically and returns a tidy tibble.

### Daily usage, last 30 days

``` r

usage <- util_fetch_usage(
  starting_at  = Sys.time() - 30 * 24 * 3600,
  ending_at    = Sys.time(),
  bucket_width = "1d"
)
usage
```

Expected output (columns depend on `group_by`):

    # A tibble: 30 × 6
       timestamp_bucket     input_tokens output_tokens cache_creation_input_tokens
       <chr>                       <int>         <int>                       <int>
     1 2026-04-01T00:00:00Z       482910        128470                      182043
     2 2026-04-02T00:00:00Z       291830         73291                       91032
     # ℹ 28 more rows
     # ℹ 2 more variables: cache_read_input_tokens <int>, n_requests <int>

### Group by model

``` r

by_model <- util_fetch_usage(
  starting_at  = Sys.time() - 7 * 24 * 3600,
  ending_at    = Sys.time(),
  bucket_width = "1d",
  group_by     = "model"
)
by_model
```

### Hourly usage for a single day

``` r

hourly <- util_fetch_usage(
  starting_at  = "2026-05-01T00:00:00Z",
  ending_at    = "2026-05-01T23:59:59Z",
  bucket_width = "1h"
)
```

### Filter by specific models

``` r

opus_only <- util_fetch_usage(
  starting_at  = Sys.time() - 14 * 24 * 3600,
  ending_at    = Sys.time(),
  bucket_width = "1d",
  models       = c("claude-opus-4-7", "claude-opus-4")
)
```

------------------------------------------------------------------------

## Fetching cost data

[`util_fetch_cost()`](https://mjfrigaard.github.io/shokenuse/reference/util_fetch_cost.md)
wraps `GET /v1/organizations/cost_report`. Costs are daily only
(`bucket_width = "1d"` is fixed).

``` r

costs <- util_fetch_cost(
  starting_at = Sys.time() - 30 * 24 * 3600,
  ending_at   = Sys.time()
)
costs
```

Group by workspace for chargeback reporting:

``` r

by_workspace <- util_fetch_cost(
  starting_at = "2026-05-01T00:00:00Z",
  ending_at   = "2026-05-31T23:59:59Z",
  group_by    = c("workspace_id", "description")
)
```

------------------------------------------------------------------------

## Visualizing API usage

Once fetched, the tibbles work directly with ggplot2.

### Daily input tokens by model

``` r

library(ggplot2)

by_model |>
  dplyr::mutate(date = as.Date(timestamp_bucket)) |>
  ggplot(aes(x = date, y = input_tokens, fill = model)) +
  geom_col() +
  scale_y_continuous(
    labels = scales::label_number(scale_cut = scales::cut_short_scale())
  ) +
  labs(x = NULL, y = "Input tokens", fill = "Model") +
  theme_minimal()
```

### Cumulative cost over time

``` r

costs |>
  dplyr::mutate(date = as.Date(timestamp_bucket)) |>
  dplyr::arrange(date) |>
  dplyr::mutate(cumulative_cost = cumsum(cost_usd)) |>
  ggplot(aes(x = date, y = cumulative_cost)) +
  geom_line() +
  geom_area(alpha = 0.2) +
  scale_y_continuous(labels = scales::dollar) +
  labs(x = NULL, y = "Cumulative cost (USD)") +
  theme_minimal()
```

------------------------------------------------------------------------

## Pagination

Both functions handle pagination internally (via `max_pages`, default
10). For very large date ranges you may need to increase this:

``` r

# Fetch up to 50 pages
big_pull <- util_fetch_usage(
  starting_at  = "2026-01-01T00:00:00Z",
  ending_at    = Sys.time(),
  bucket_width = "1d",
  max_pages    = 50L
)
```

------------------------------------------------------------------------

## Synthetic example (runs without an API key)

The structure below mirrors what
[`util_fetch_usage()`](https://mjfrigaard.github.io/shokenuse/reference/util_fetch_usage.md)
returns, so you can prototype visualizations without credentials.

``` r

library(shokenuse)

# Simulate 14 days of daily usage across two models
set.seed(42)
dates  <- seq(as.Date("2026-05-01"), by = "day", length.out = 14)
models <- c("claude-opus-4", "claude-sonnet-4")

synthetic_usage <- tidyr::expand_grid(
  timestamp_bucket = paste0(dates, "T00:00:00Z"),
  model            = models
) |>
  dplyr::mutate(
    input_tokens                = as.integer(runif(dplyr::n(), 5e4, 5e5)),
    output_tokens               = as.integer(runif(dplyr::n(), 1e4, 1e5)),
    cache_creation_input_tokens = as.integer(runif(dplyr::n(), 0,   2e5)),
    cache_read_input_tokens     = as.integer(runif(dplyr::n(), 1e5, 2e6)),
    n_requests                  = as.integer(runif(dplyr::n(), 10,  200))
  )

synthetic_usage
#> # A tibble: 28 × 7
#>    timestamp_bucket     model  input_tokens output_tokens cache_creation_input…¹
#>    <chr>                <chr>         <int>         <int>                  <int>
#>  1 2026-05-01T00:00:00Z claud…       461662         50227                 135455
#>  2 2026-05-01T00:00:00Z claud…       471683         85240                  34252
#>  3 2026-05-02T00:00:00Z claud…       178762         76383                  52217
#>  4 2026-05-02T00:00:00Z claud…       423701         82994                 102882
#>  5 2026-05-03T00:00:00Z claud…       338785         44929                 135121
#>  6 2026-05-03T00:00:00Z claud…       283593         71665                 196563
#>  7 2026-05-04T00:00:00Z claud…       381464         10355                 151908
#>  8 2026-05-04T00:00:00Z claud…       110599         84962                 113297
#>  9 2026-05-05T00:00:00Z claud…       345646         10660                 169937
#> 10 2026-05-05T00:00:00Z claud…       367279         28689                  37894
#> # ℹ 18 more rows
#> # ℹ abbreviated name: ¹​cache_creation_input_tokens
#> # ℹ 2 more variables: cache_read_input_tokens <int>, n_requests <int>
```

Add estimated costs using the package pricing table:

``` r

synthetic_costed <- synthetic_usage |>
  dplyr::rename(
    cache_creation_tokens = cache_creation_input_tokens,
    cache_read_tokens     = cache_read_input_tokens
  ) |>
  dplyr::mutate(
    timestamp   = as.POSIXct(timestamp_bucket, tz = "UTC"),
    machine     = "api",
    source      = "anthropic_api",
    project     = NA_character_,
    session_id  = NA_character_
  ) |>
  util_add_cost()

util_summarise_usage(synthetic_costed, by = "model")
#> # A tibble: 2 × 8
#>   model       input_tokens cache_creation_tokens cache_read_tokens output_tokens
#>   <chr>              <int>                 <int>             <int>         <int>
#> 1 claude-opu…      4709386               1221473          15922926        677191
#> 2 claude-son…      4400817               1202590          14512778        994141
#> # ℹ 3 more variables: cost_usd <dbl>, n_requests <int>, total_tokens <int>
```

------------------------------------------------------------------------

## Integrating with the dashboard

API data can be merged into the dashboard in two ways:

### Interactively (via the Data tab)

Open the **Data** tab, enter your `sk-ant-admin...` key, give the source
a **Machine label** (e.g. `"org-name"`), click **Fetch Usage**, then
click **Add to Dashboard**. Repeat with a different key to load data
from another organization — each fetch appends to the existing dashboard
data.

### Programmatically (before launching)

``` r

api_usage <- util_fetch_usage(
  starting_at = Sys.time() - 30 * 24 * 3600,
  group_by    = "model"
)

# Convert to the usage schema expected by util_combine_usage()
api_rows <- api_usage |>
  dplyr::mutate(
    timestamp             = as.POSIXct(timestamp_bucket, tz = "UTC"),
    machine               = "api",
    source                = "anthropic_api",
    project               = NA_character_,
    session_id            = NA_character_,
    cache_creation_tokens = cache_creation_input_tokens,
    cache_read_tokens     = cache_read_input_tokens,
    date                  = as.Date(timestamp)
  ) |>
  dplyr::select(timestamp, date, machine, source, project, session_id,
                model, input_tokens, cache_creation_tokens,
                cache_read_tokens, output_tokens) |>
  util_add_cost()

# Optionally combine with other data before inspecting
all_usage <- util_combine_usage(api_rows, util_read_usage_csv("export.csv"))
util_summarise_usage(all_usage, by = "model")

launch_app()
```
