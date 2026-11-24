# Anthropic model pricing (USD per million tokens)

Returns per-million-token prices for input, output, cache creation, and
cache read for known Claude models. Update when Anthropic changes
pricing.

## Usage

``` r
util_model_pricing()
```

## Value

Tibble with columns \`model\`, \`input_pm\`, \`output_pm\`,
\`cache_write_pm\`, \`cache_read_pm\`.
