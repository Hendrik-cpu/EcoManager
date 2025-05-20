#!/bin/bash

START_PATH="${1:-.}"
OUTFILE=".mapping/output/references.graph.json"
TMPFILE=".mapping/raw/references.raw"

echo "🔍 Scanning references from: $START_PATH"
mkdir -p ./mapping/raw

# Leere temporäre Datei
> "$TMPFILE"

# Suche nach Import-/Verknüpfungsbegriffen
grep -rE 'require\(|import |source |COPY |ADD |RUN |CMD |exec |uses: |run:' "$START_PATH"   --exclude-dir=node_modules   --exclude-dir=.git   --exclude-dir=mapping   --exclude=*.lock   --exclude=*.png   --exclude=*.jpg   --exclude=*.gif   --exclude-dir=coverage   --exclude-dir=dist   --binary-files=without-match   > "$TMPFILE"

# Konvertiere in JSON-ähnliches Mapping
echo "{" > "$OUTFILE"
awk -F: '{gsub(/^\./, "", $1); gsub(/^\//, "", $1); printf "  \"%s\": [],\n", $1}' "$TMPFILE" | sort -u >> "$OUTFILE"
sed -i '$ s/,$//' "$OUTFILE"
echo "}" >> "$OUTFILE"

echo "✅ Reference graph saved to: $OUTFILE"
