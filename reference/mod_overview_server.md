# Overview tab module server

Owns filter state and computes the filtered reactive returned to the
main server for use by all other modules.

## Usage

``` r
mod_overview_server(id, raw_usage_rv)
```

## Arguments

- id:

  Shiny module ID.

- raw_usage_rv:

  \`reactiveVal\` holding the full usage tibble.

## Value

A reactive tibble of filtered usage data.
