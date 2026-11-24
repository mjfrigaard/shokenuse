# Primary application server

Wires together all module servers and passes reactive data between them.
The overview module owns the filter state and returns the \`filtered\`
reactive consumed by all other modules. Data is loaded exclusively via
the Data tab (Admin API fetch or CSV upload).

## Usage

``` r
app_server()
```

## Value

A Shiny server function.
