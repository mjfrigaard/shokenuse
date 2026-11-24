# Summarise usage by grouping variables

Summarise usage by grouping variables

## Usage

``` r
util_summarise_usage(usage, by = "date")
```

## Arguments

- usage:

  Tibble from \[util_read_claude_code()\] or \[util_combine_usage()\].

- by:

  Character vector of grouping column names. Default \`"date"\`.

## Value

Summarised tibble with token totals, cost, \`n_requests\`, and
\`total_tokens\`.
