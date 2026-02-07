#!/bin/bash
# Simple analyzer checker script to count Dart issues

cd /workspaces/MASLIVE/app

echo "=========================================="
echo "Dart Analyzer Issue Count"
echo "=========================================="

# Run analyzer and format as machine-readable
dart analyze --format=machine 2>&1 | \
  awk -F'|' '{print $3}' | \
  sort | uniq -c | sort -rn

echo ""
echo "=========================================="
echo "Total lines with issues:"
dart analyze 2>&1 | wc -l

echo ""
echo "Press Enter to see full output (first 50 lines):"
read
dart analyze 2>&1 | head -50
