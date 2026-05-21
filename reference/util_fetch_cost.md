# Fetch cost data from the Anthropic Admin API

Calls \`GET /v1/organizations/cost_report\` (daily granularity only).
Requires an Admin API key from an organization account.

## Usage

``` r
util_fetch_cost(
  starting_at,
  ending_at = Sys.time(),
  group_by = character(),
  api_key = Sys.getenv("ANTHROPIC_ADMIN_KEY"),
  max_pages = 10L
)
```

## Arguments

- starting_at:

  Start of window (POSIXct or ISO-8601 string).

- ending_at:

  End of window. Defaults to current time.

- group_by:

  Character vector of grouping dimensions: \`"workspace_id"\`,
  \`"description"\`.

- api_key:

  Admin API key. Defaults to \`ANTHROPIC_ADMIN_KEY\` env var.

- max_pages:

  Maximum pagination pages to fetch.

## Value

Tibble with cost data in USD.
