#!/bin/bash
# analyze.sh - Analyze a RISC-V simulation log file.
# Usage: ./scripts/analyze.sh <logfile> [options]      (run with --help for the list)
# Exit code: 0 if every test passed, 1 if any test failed, 2 on usage errors.

# -e: stop on error | -u: error on unset variables | pipefail: a pipe fails if any part fails
set -euo pipefail

# ---------- Default settings ----------
FORMAT="text"
OUTPUT=""
VERBOSE=0
LOGFILE=""
BASELINE=""
COLOR="auto"
GREEN=""; RED=""; YELLOW=""; RESET=""    # filled in by setup_colors

# ---------- Function 1: print help ----------
usage() {
    cat <<USAGE
Usage: $(basename "$0") <logfile> [options]

Analyze a RISC-V simulation log and print a summary report.

Options:
  --format [text|csv]    Output format (default: text)
  --output <path>        Write the report to a file (default: stdout)
  --compare <baseline>   Compare with an older log and list regressions
                         (tests that passed before but fail now; text format only)
  --color | --no-color   Force colors on or off (default: automatic, colors are
                         used only when printing to a terminal)
  --verbose              Print extra progress info and per-test times
  --help                 Show this help message

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
            --help)     usage; exit 0 ;;
            --verbose)  VERBOSE=1; shift ;;
            --color)    COLOR="always"; shift ;;
            --no-color) COLOR="never"; shift ;;
            --format)
                [[ $# -ge 2 ]] || die "--format needs a value (text or csv)"
                FORMAT="$2"; shift 2 ;;
            --output)
                [[ $# -ge 2 ]] || die "--output needs a file path"
                OUTPUT="$2"; shift 2 ;;
            --compare)
                [[ $# -ge 2 ]] || die "--compare needs a baseline log file"
                BASELINE="$2"; shift 2 ;;
            -*)         die "unknown option: $1" ;;
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
    if [[ -n $BASELINE ]]; then
        [[ -f $BASELINE ]] || die "baseline file not found: $BASELINE"
        [[ $FORMAT == text ]] || die "--compare only works with --format text"
    fi
}

# ---------- Function 5: turn on ANSI colors only when appropriate ----------
setup_colors() {
    # Auto mode: color only if stdout is a terminal (-t 1) and we are not writing to a file
    if [[ $COLOR == always || ( $COLOR == auto && -t 1 && -z $OUTPUT ) ]]; then
        GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
    fi
}

# ---------- Function 6: one line per finished test ----------
# Prints: name,STATUS,time   (time is empty for SKIP)
extract_rows() {
    # Fields in "[date time] TEST PASS: name (0.82s)": $4=status $5=name
    awk '/TEST (PASS|FAIL|SKIP):/ {
        status = $4; sub(":", "", status)
        time = ""
        if (match($0, /\([0-9.]+s\)/)) {
            time = substr($0, RSTART + 1, RLENGTH - 3)   # strip "(" and "s)"
        }
        print $5 "," status "," time
    }' "$1"
}

# ---------- Function 7: tests that passed in the baseline but fail now ----------
find_regressions() {
    # First input = baseline rows, second input = current rows.
    # NR==FNR is true only while reading the first input.
    awk -F, 'NR == FNR { base[$1] = $2; next }
             $2 == "FAIL" && base[$1] == "PASS" { print $1 }' \
        <(extract_rows "$BASELINE") <(echo "$ROWS")
}

# ---------- Function 8: pull numbers out of the log ----------
analyze_log() {
    log_verbose "Reading $LOGFILE"

    # grep -c counts matching lines. It exits with 1 when the count is 0,
    # which would kill the script under 'set -e', so we add '|| true'.
    PASS=$(grep -c 'TEST PASS:' "$LOGFILE" || true)
    FAIL=$(grep -c 'TEST FAIL:' "$LOGFILE" || true)
    SKIP=$(grep -c 'TEST SKIP:' "$LOGFILE" || true)
    TOTAL=$((PASS + FAIL + SKIP))

    ROWS=$(extract_rows "$LOGFILE")

    # Names of failing tests, one per line
    FAILED_TESTS=$(echo "$ROWS" | awk -F, '$2 == "FAIL" { print $1 }')

    # Regressions only make sense when a baseline was given
    REGRESSIONS=""
    if [[ -n $BASELINE ]]; then
        log_verbose "Comparing against $BASELINE"
        REGRESSIONS=$(find_regressions)
    fi

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

# ---------- Function 9: percentage helper (avoids dividing by zero) ----------
percent() {
    awk -v n="$1" -v total="$2" 'BEGIN { if (total == 0) print "0.0"; else printf "%.1f", n * 100 / total }'
}

# ---------- Function 10: human-readable report ----------
print_text_report() {
    # Failed count is only red when there really are failures
    local fail_color=""
    if [[ $FAIL -gt 0 ]]; then fail_color="$RED"; fi

    echo "=== RISC-V Simulation Log Analysis ==="
    echo "Log file: $LOGFILE"
    echo "Analysis date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    echo "--- Results Summary ---"
    echo "Total tests: $TOTAL"
    printf "%sPassed:  %9d (%4.1f%%)%s\n" "$GREEN" "$PASS" "$(percent "$PASS" "$TOTAL")" "$RESET"
    printf "%sFailed:  %9d (%4.1f%%)%s\n" "$fail_color" "$FAIL" "$(percent "$FAIL" "$TOTAL")" "$RESET"
    printf "%sSkipped: %9d (%4.1f%%)%s\n" "$YELLOW" "$SKIP" "$(percent "$SKIP" "$TOTAL")" "$RESET"
    echo
    echo "--- Failed Tests ---"
    if [[ $FAIL -eq 0 ]]; then
        echo "  (none)"
    else
        echo "$FAILED_TESTS" | awk -v c="$RED" -v r="$RESET" '{ printf "  %s%d. %s%s\n", c, NR, $0, r }'
    fi

    if [[ -n $BASELINE ]]; then
        echo
        echo "--- Regressions vs $BASELINE ---"
        if [[ -z $REGRESSIONS ]]; then
            echo "  (none)"
        else
            echo "$REGRESSIONS" | awk -v c="$RED" -v r="$RESET" '{ printf "  %s%d. %s (passed before, fails now)%s\n", c, NR, $0, r }'
        fi
    fi

    echo
    echo "--- Timing Statistics ---"
    echo "Min time:     $MIN_T ($MIN_N)"
    echo "Max time:     $MAX_T ($MAX_N)"
    echo "Avg time:     $AVG_T"

    if [[ $VERBOSE -eq 1 ]]; then
        echo
        echo "--- Per-Test Times ---"
        # Pick a color per status: green PASS, red FAIL, yellow everything else
        echo "$ROWS" | awk -F, -v g="$GREEN" -v r="$RED" -v y="$YELLOW" -v z="$RESET" '{
            c = ($2 == "PASS") ? g : (($2 == "FAIL") ? r : y)
            printf "  %-14s %s%-5s%s %s\n", $1, c, $2, z, ($3 == "" ? "-" : $3 "s")
        }'
    fi

    echo
    if [[ $FAIL -eq 0 ]]; then
        echo "${GREEN}--- Verdict: PASS ---${RESET}"
        echo "Exit code: 0"
    else
        echo "${RED}--- Verdict: FAIL ---${RESET}"
        echo "Exit code: 1"
    fi
}

# ---------- Function 11: machine-readable report ----------
print_csv_report() {
    echo "test,status,time_seconds"
    echo "$ROWS"
}

# ---------- Main program ----------
main() {
    parse_args "$@"
    setup_colors
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
