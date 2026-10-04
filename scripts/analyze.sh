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

# ---------- Function 5: pull numbers out of the log ----------
analyze_log() {
    log_verbose "Reading $LOGFILE"

    # grep -c counts matching lines. It exits with 1 when the count is 0,
    # which would kill the script under 'set -e', so we add '|| true'.
    PASS=$(grep -c 'TEST PASS:' "$LOGFILE" || true)
    FAIL=$(grep -c 'TEST FAIL:' "$LOGFILE" || true)
    SKIP=$(grep -c 'TEST SKIP:' "$LOGFILE" || true)
    TOTAL=$((PASS + FAIL + SKIP))

    # One line per finished test: name,STATUS,time   (time is empty for SKIP)
    # Fields in "[date time] TEST PASS: name (0.82s)": $4=status $5=name $6=(time)
    ROWS=$(awk '/TEST (PASS|FAIL|SKIP):/ {
        status = $4; sub(":", "", status)
        time = ""
        if (match($0, /\([0-9.]+s\)/)) {
            time = substr($0, RSTART + 1, RLENGTH - 3)   # strip "(" and "s)"
        }
        print $5 "," status "," time
    }' "$LOGFILE")

    # Names of failing tests, one per line
    FAILED_TESTS=$(echo "$ROWS" | awk -F, '$2 == "FAIL" { print $1 }')

    # Timing statistics from rows that have a time
    MIN_T="n/a"; MIN_N="-"; MAX_T="n/a"; MAX_N="-"; AVG_T="n/a"
    if echo "$ROWS" | awk -F, '$3 != ""' | grep -q .; then
        read -r MIN_T MIN_N MAX_T MAX_N AVG_T < <(
            echo "$ROWS" | awk -F, '$3 != "" {
                if (n == 0 || $3 < min) { min = $3; minn = $1 }
                if (n == 0 || $3 > max) { max = $3; maxn = $1 }
                sum += $3; n++
            } END { printf "%.2f %s %.2f %s %.2f\n", min, minn, max, maxn, sum / n }'
        )
        MIN_T+="s"; MAX_T+="s"; AVG_T+="s"   # add the unit once we know there is a number
    fi
    log_verbose "Found $TOTAL tests ($PASS pass, $FAIL fail, $SKIP skip)"
}

# ---------- Function 6: percentage helper (avoids dividing by zero) ----------
percent() {
    awk -v n="$1" -v total="$2" 'BEGIN { if (total == 0) print "0.0"; else printf "%.1f", n * 100 / total }'
}

# ---------- Function 7: human-readable report ----------
print_text_report() {
    echo "=== RISC-V Simulation Log Analysis ==="
    echo "Log file: $LOGFILE"
    echo "Analysis date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    echo "--- Results Summary ---"
    echo "Total tests: $TOTAL"
    printf "Passed:  %9d (%4.1f%%)\n" "$PASS" "$(percent "$PASS" "$TOTAL")"
    printf "Failed:  %9d (%4.1f%%)\n" "$FAIL" "$(percent "$FAIL" "$TOTAL")"
    printf "Skipped: %9d (%4.1f%%)\n" "$SKIP" "$(percent "$SKIP" "$TOTAL")"
    echo
    echo "--- Failed Tests ---"
    if [[ $FAIL -eq 0 ]]; then
        echo "  (none)"
    else
        echo "$FAILED_TESTS" | awk '{ printf "  %d. %s\n", NR, $0 }'
    fi
    echo
    echo "--- Timing Statistics ---"
    echo "Min time:     $MIN_T ($MIN_N)"
    echo "Max time:     $MAX_T ($MAX_N)"
    echo "Avg time:     $AVG_T"

    if [[ $VERBOSE -eq 1 ]]; then
        echo
        echo "--- Per-Test Times ---"
        echo "$ROWS" | awk -F, '{ printf "  %-14s %-5s %s\n", $1, $2, ($3 == "" ? "-" : $3 "s") }'
    fi

    echo
    if [[ $FAIL -eq 0 ]]; then
        echo "--- Verdict: PASS ---"
        echo "Exit code: 0"
    else
        echo "--- Verdict: FAIL ---"
        echo "Exit code: 1"
    fi
}

# ---------- Function 8: machine-readable report ----------
print_csv_report() {
    echo "test,status,time_seconds"
    echo "$ROWS"
}

# ---------- Main program ----------
main() {
    parse_args "$@"
    analyze_log

    local report_fn="print_${FORMAT}_report"   # builds "print_text_report" or "print_csv_report"
    if [[ -n $OUTPUT ]]; then
        mkdir -p "$(dirname "$OUTPUT")"
        "$report_fn" > "$OUTPUT"
        log_verbose "Report written to $OUTPUT"
    else
        "$report_fn"
    fi

    # Exit code is what makes this script usable in Makefiles and CI
    if [[ $FAIL -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
