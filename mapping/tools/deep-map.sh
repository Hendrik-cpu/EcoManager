#!/bin/bash

START_FILE="$1"
OUTDIR=".mapping/output"
RAW_LOG="$OUTDIR/raw.log"
STRUCT_JSON="$OUTDIR/structure.tree.json"

mkdir -p "$OUTDIR"
echo "🧠 Deep mapping from entry point: $START_FILE" > "$RAW_LOG"

grep -rE 'include|require|import|FROM|COPY|RUN|exec|source|uses:|run:' . >> "$RAW_LOG"
find . -type f \( -name "*.env" -o -name "*.yml" -o -name "Dockerfile*" -o -name "*.sh" -o -name "*.feature" \) >> "$RAW_LOG"
tree -J -L 3 > "$STRUCT_JSON"

echo "✅ Deep mapping complete."
echo "↪︎ Raw log: $RAW_LOG"
echo "↪︎ Structure: $STRUCT_JSON"
