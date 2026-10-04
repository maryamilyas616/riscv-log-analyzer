#!/bin/bash
# generate_report.sh - Run analyze.sh on one or more logs and save reports.
# Usage: ./scripts/generate_report.sh <log1> [log2 ...]
# Writes output/<name>.txt for each log plus output/summary.txt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${OUT_DIR:-output}"      # can be overridden: OUT_DIR=/tmp/x ./generate_report.sh ...

[[ $# -gt 0 ]] || { echo "Usage: $0 <logfile> [logfile ...]" >&2; exit 2; }

mkdir -p "$OUT_DIR"
SUMMARY="$OUT_DIR/summary.txt"
echo "Report summary - generated $(date '+%Y-%m-%d %H:%M:%S')" > "$SUMMARY"
echo "======================================================" >> "$SUMMARY"

for log in "$@"; do
    name=$(basename "$log" .log)
    report="$OUT_DIR/${name}.txt"

    # analyze.sh exits 1 when tests fail. That is a normal result here,
    # so we capture the exit code instead of letting 'set -e' abort.
    rc=0
    "$SCRIPT_DIR/analyze.sh" "$log" --output "$report" || rc=$?
    if [[ $rc -gt 1 ]]; then
        echo "Error: analysis of $log failed (exit $rc)" >&2
        exit "$rc"
    fi

    verdict="PASS"; [[ $rc -eq 1 ]] && verdict="FAIL"
    {
        echo
        echo "$name  ->  $verdict"
        grep -E '^(Total tests|Passed|Failed|Skipped)' "$report" | sed 's/^/    /'
    } >> "$SUMMARY"
    echo "Wrote $report"
done
echo "Wrote $SUMMARY"
