#!/bin/bash
# Rebuild every round: the contact sheet HTML, the standalone SVGs, and a 2x PNG of the sheet.
# Needs python3 with numpy and Pillow, and node with playwright (the Claude cloud container has both).
set -euo pipefail
cd "$(dirname "$0")"
ROUNDS=../rounds
for script in round1_styles round3_concepts round4_marks; do
  python3 "$script.py"
done
for dir in round-1-styles round-3-concepts round-4-marks; do
  node render.cjs "$ROUNDS/$dir/index.html" "$ROUNDS/$dir/sheet.png" 2
done
