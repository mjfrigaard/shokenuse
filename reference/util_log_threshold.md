# Set the logging threshold for shokenuse

Controls the verbosity of shokenuse log output. Use \`"DEBUG"\` to see
per-file and per-request detail; \`"INFO"\` for normal operation;
\`"OFF"\` to silence all output.

## Usage

``` r
util_log_threshold(level = "INFO")
```

## Arguments

- level:

  One of \`"TRACE"\`, \`"DEBUG"\`, \`"INFO"\` (default), \`"WARN"\`,
  \`"ERROR"\`, \`"FATAL"\`, or \`"OFF"\`.

## Value

\`NULL\` invisibly.
