# Fetch token usage from the Anthropic Admin API

Calls \`GET /v1/organizations/usage_report/messages\`. Handles
pagination automatically. Requires an Admin API key from an organization
account — not available for individual (personal) accounts.

## Usage

``` r
util_fetch_usage(
  starting_at,
  ending_at = Sys.time(),
  bucket_width = c("1d", "1h", "1m"),
  group_by = character(),
  models = character(),
  api_key = Sys.getenv("ANTHROPIC_ADMIN_KEY"),
  max_pages = 10L
)
```

## Arguments

- starting_at:

  Start of window (POSIXct or ISO-8601 string).

- ending_at:

  End of window. Defaults to current time.

- bucket_width:

  Aggregation interval: \`"1d"\`, \`"1h"\`, or \`"1m"\`.

- group_by:

  Character vector of dimensions to group by. Valid values: \`"model"\`,
  \`"workspace_id"\`, \`"api_key_id"\`, \`"service_tier"\`.

- models:

  Character vector of model names to filter; empty = all.

- api_key:

  Admin API key. Defaults to \`ANTHROPIC_ADMIN_KEY\` env var.

- max_pages:

  Maximum pagination pages to fetch (safety cap).

## Value

Tibble with \`timestamp_bucket\`, \`input_tokens\`, \`output_tokens\`,
\`cache_creation_input_tokens\`, \`cache_read_input_tokens\`, and any
grouping columns present in the response.

## Details

Response structure: top-level \`data\` array of time buckets, each with
\`starting_at\`, \`ending_at\`, and a nested \`results\` array of
records. Token counts use \`uncached_input_tokens\` and a nested
\`cache_creation\` object rather than a flat \`input_tokens\` field.
