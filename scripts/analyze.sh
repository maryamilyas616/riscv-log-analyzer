#!/bin/bash
# analyze.sh - Analyze a RISC-V simulation log file.
# Usage: ./scripts/analyze.sh <logfile> [--format text|csv] [--output <path>] [--verbose] [--help]
# Exit code: 0 if every test passed, 1 if any test failed, 2 on usage errors.

# -e: stop on error | -u: error on unset variables | pipefail: a pipe fails if any part fails
set -euo pipefail

# ---------- Default settings ----------
FORMAT="text"
OUTPUT=""
VERBOSE=0
LOGFILE=""

# ---------- Function 1: print help ----------
usage() {
    cat <<USAGE
Usage: $(basename "$0") <logfile> [options]

Analyze a RISC-V simulation log and print a summary report.

Options:
  --format [text|csv]   Output format (default: text)
  --output <path>       Write the report to a file (default: stdout)
  --verbose             Print extra progress info and per-test times
  --help                Show this help message

Exit codes: 0 = all tests passed, 1 = at least one test failed, 2 = usage error
USAGE
}

# ---------- Function 2: print an error and quit ----------
die() {
    echo "Error: $*" >&2      # >&2 sends the message to stderr, not stdout
    echo "Try '$(basename "$0") --help' for usage." >&2
    exit 2
}

# ---------- Function 3: print only when --verbose is on ----------
log_verbose() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo "[verbose] $*" >&2
    fi
}

# ---------- Function 4: read and validate command-line arguments ----------
parse_args() {
    [[ $# -gt 0 ]] || die "missing log file argument"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)    usage; exit 0 ;;
            --verbose) VERBOSE=1; shift ;;
            --format)
                [[ $# -ge 2 ]] || die "--format needs a value (text or csv)"
                FORMAT="$2"; shift 2 ;;
            --output)
                [[ $# -ge 2 ]] || die "--output needs a file path"
                OUTPUT="$2"; shift 2 ;;
            -*)        die "unknown option: $1" ;;
            *)
                [[ -z $LOGFILE ]] || die "only one log file allowed (got extra: $1)"
                LOGFILE="$1"; shift ;;
        esac
    done

    [[ -n $LOGFILE ]] || die "missing log file argument"
    [[ -f $LOGFILE ]] || die "file not found: $LOGFILE"
    [[ -r $LOGFILE ]] || die "file is not readable: $LOGFILE"
    case "$FORMAT" in
        text|csv) ;;
        *) die "invalid format '$FORMAT' (use text or csv)" ;;
    esac
}
