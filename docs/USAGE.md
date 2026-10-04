# Usage Guide

## analyze.sh

    ./scripts/analyze.sh <logfile> [--format text|csv] [--output <path>] [--verbose] [--help]

| Option | Meaning |
|--------|---------|
| `<logfile>` | Path to the log file (required) |
| `--format text\|csv` | Output format. Default: `text` |
| `--output <path>` | Write the report to a file. Default: print to screen |
| `--verbose` | Show progress messages and per-test times |
| `--help` | Show the help text |

Exit codes: `0` all tests passed, `1` at least one test failed, `2` bad usage.

## Examples

    ./scripts/analyze.sh test_data/sample_pass.log
    ./scripts/analyze.sh test_data/sample_fail.log --format csv
    ./scripts/analyze.sh test_data/sample_fail.log --output output/fail.txt --verbose

## Other scripts

- `scripts/setup_env.sh` - checks that the required tools are installed.
- `scripts/generate_report.sh <log...>` - writes one report per log plus `output/summary.txt`.

## Make targets

Run `make help` to list them: `all`, `test`, `report`, `clean`, `setup`, `help`.
