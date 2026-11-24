# Combine usage data frames from multiple sources

Row-binds any number of data frames from \[util_read_claude_code()\] or
\[util_read_usage_csv()\] and sorts by timestamp.

## Usage

``` r
util_combine_usage(...)
```

## Arguments

- ...:

  Data frames to combine.

## Value

Single tibble sorted by timestamp.
