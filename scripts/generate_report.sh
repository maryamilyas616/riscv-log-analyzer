#!/bin/bash
# generate_report.sh - Run analyze.sh on one or more logs and save reports.
# Usage: ./scripts/generate_report.sh <log1> [log2 ...]
# Writes output/<name>.txt for each log, plus output/summary.txt
# and one combined HTML report with a results table: output/report.html
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${OUT_DIR:-output}"      # can be overridden: OUT_DIR=/tmp/x ./generate_report.sh ...

[[ $# -gt 0 ]] || { echo "Usage: $0 <logfile> [logfile ...]" >&2; exit 2; }

mkdir -p "$OUT_DIR"
SUMMARY="$OUT_DIR/summary.txt"
HTML="$OUT_DIR/report.html"

echo "Report summary - generated $(date '+%Y-%m-%d %H:%M:%S')" > "$SUMMARY"
echo "======================================================" >> "$SUMMARY"

# ---------- Start of the HTML page (inline CSS so it is a single file) ----------
cat > "$HTML" <<HTML_HEAD
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>RISC-V Log Analysis Report</title>
<style>
  body  { font-family: Arial, sans-serif; margin: 2em; color: #222; }
  table { border-collapse: collapse; margin-bottom: 2em; min-width: 360px; }
  th, td { border: 1px solid #ccc; padding: 6px 12px; text-align: left; }
  th    { background: #f0f0f0; }
  .pass { color: #1a7f37; font-weight: bold; }
  .fail { color: #cf222e; font-weight: bold; }
  .skip { color: #9a6700; font-weight: bold; }
</style>
</head>
<body>
<h1>RISC-V Log Analysis Report</h1>
<p>Generated $(date '+%Y-%m-%d %H:%M:%S')</p>
HTML_HEAD

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

    verdict="PASS"; css="pass"
    if [[ $rc -eq 1 ]]; then verdict="FAIL"; css="fail"; fi

    # ----- text summary -----
    {
        echo
        echo "$name  ->  $verdict"
        grep -E '^(Total tests|Passed|Failed|Skipped)' "$report" | sed 's/^/    /'
    } >> "$SUMMARY"

    # ----- HTML section: the CSV output is easy to turn into table rows -----
    csv=$("$SCRIPT_DIR/analyze.sh" "$log" --format csv) || true
    {
        echo "<h2>$name &mdash; <span class=\"$css\">$verdict</span></h2>"
        echo "<table>"
        echo "<tr><th>Test</th><th>Status</th><th>Time (s)</th></tr>"
        # tail -n +2 skips the CSV header; the class name is the lowercase status
        echo "$csv" | tail -n +2 | awk -F, 'NF {
            printf "<tr><td>%s</td><td class=\"%s\">%s</td><td>%s</td></tr>\n", $1, tolower($2), $2, ($3 == "" ? "-" : $3)
        }'
        echo "</table>"
    } >> "$HTML"

    echo "Wrote $report"
done

echo "</body></html>" >> "$HTML"
echo "Wrote $SUMMARY"
echo "Wrote $HTML"
