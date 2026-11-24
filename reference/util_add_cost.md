# Add estimated cost column to a usage tibble

Joins each row's model to \[util_model_pricing()\] and appends a
\`cost_usd\` column. Models not found in the table fall back to
\`"unknown"\` prices.

## Usage

``` r
util_add_cost(usage)
```

## Arguments

- usage:

  Tibble from \[util_read_claude_code()\] or \[util_combine_usage()\].

## Value

Input tibble with \`cost_usd\` appended.
