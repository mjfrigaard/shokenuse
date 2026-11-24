# Launch the shokenuse Shiny dashboard

Convenience wrapper around \[shiny::shinyApp()\] that wires together
\[app_ui()\] and \[app_server()\]. Load data via the Data tab using an
Anthropic Admin API key or by uploading a CSV file.

## Usage

``` r
launch_app(...)
```

## Arguments

- ...:

  Additional arguments passed to \[shiny::shinyApp()\].

## Value

A Shiny app object (invisibly when run interactively).
