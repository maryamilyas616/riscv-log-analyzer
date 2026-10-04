**Status:** Scripts, Makefile and docs complete

## Installation

    git clone git@github.com:maryamilyas616/riscv-log-analyzer.git
    cd riscv-log-analyzer
    make setup        # checks that bash, grep, awk, sed, git and make are installed

## Usage

    ./scripts/analyze.sh <logfile> [--format text|csv] [--output <path>] [--verbose] [--help]

Examples:

    ./scripts/analyze.sh test_data/sample_fail.log
    ./scripts/analyze.sh test_data/sample_fail.log --format csv
    ./scripts/analyze.sh test_data/sample_pass.log --output output/pass.txt
    make test         # verify the analyzer against the sample logs
    make report       # write reports + summary into output/
    make help         # list every make target

Exit code is `0` when all tests pass and `1` when any test fails.
See [docs/USAGE.md](docs/USAGE.md) for the full command reference.

## Sample output

```
=== RISC-V Simulation Log Analysis ===
Log file: test_data/sample_fail.log
Analysis date: 2026-10-05 01:35:50

--- Results Summary ---
Total tests: 9
Passed:          6 (66.7%)
Failed:          2 (22.2%)
Skipped:         1 (11.1%)

--- Failed Tests ---
  1. rv32i-sll
  2. rv32i-beq

--- Timing Statistics ---
Min time:     0.42s (rv32i-nop)
Max time:     2.31s (rv32i-mul)
Avg time:     0.94s

--- Verdict: FAIL ---
Exit code: 1
```
