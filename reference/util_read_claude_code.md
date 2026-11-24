# Read token usage from Claude Code JSONL files

Scans all JSONL files under \`claude_dir\` recursively and extracts
token usage from assistant messages. Each row is one API response.

## Usage

``` r
util_read_claude_code(
  claude_dir = fs::path_home(".claude", "projects"),
  machine = "local"
)
```

## Arguments

- claude_dir:

  Path to the Claude projects directory. Defaults to
  \`~/.claude/projects\`.

- machine:

  Label stored in the \`machine\` column, e.g. \`"macOS"\`.

## Value

Tibble with columns \`timestamp\`, \`machine\`, \`source\`, \`project\`,
\`session_id\`, \`model\`, \`input_tokens\`, \`cache_creation_tokens\`,
\`cache_read_tokens\`, \`output_tokens\`.
