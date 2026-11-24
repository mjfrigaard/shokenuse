# Read a manually exported usage CSV

Required columns: \`timestamp\`, \`source\`, \`model\`,
\`input_tokens\`, \`output_tokens\`. Optional: \`machine\`, \`project\`,
\`session_id\`, \`cache_creation_tokens\`, \`cache_read_tokens\`.

## Usage

``` r
util_read_usage_csv(path, machine = "manual")
```

## Arguments

- path:

  Path to CSV file.

- machine:

  Machine label used when no \`machine\` column is present.

## Value

Tibble matching the schema of \[util_read_claude_code()\].
