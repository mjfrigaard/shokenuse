# Summarise token usage by session

Aggregates to one row per session (\`session_id\`). Outliers are
sessions whose cost exceeds mean + 2 SD. When SD is zero or undefined no
session is flagged.

## Usage

``` r
util_summarise_sessions(usage)
```

## Arguments

- usage:

  Tibble from \[util_read_claude_code()\] or \[util_combine_usage()\].
  Cost is computed automatically if \`cost_usd\` is absent.

## Value

One-row-per-session tibble with \`session_id\`, \`project\`,
\`machine\`, \`source\`, \`date\`, \`duration_min\`, \`models\`,
\`n_requests\`, token columns, \`total_tokens\`, \`cost_usd\`,
\`outlier\`. Ordered by descending \`cost_usd\`.
