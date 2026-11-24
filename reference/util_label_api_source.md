# Attach friendly source labels to Admin API usage rows

Calls \`GET /v1/organizations/api_keys\` to map each opaque
\`api_key_id\` returned by \[util_fetch_usage()\] (when grouped by
\`api_key_id\`) to the API key name set in the Anthropic Console, then
applies a \`name → label\` lookup to populate a \`source\` column
matching the JSONL pathway. Key names not present in \`labels\` fall
through to the raw key name; rows with no matching key fall back to
\`"anthropic_api"\`.

## Usage

``` r
util_label_api_source(
  usage,
  labels = .api_source_labels,
  api_key = Sys.getenv("ANTHROPIC_ADMIN_KEY"),
  max_pages = 10L
)
```

## Arguments

- usage:

  Tibble from \[util_fetch_usage()\] with an \`api_key_id\` column.

- labels:

  Named character vector: API key names → source labels.

- api_key:

  Admin API key. Defaults to \`ANTHROPIC_ADMIN_KEY\` env var.

- max_pages:

  Maximum pagination pages when fetching the key list.

## Value

\`usage\` with \`api_key_name\` and \`source\` columns appended.
