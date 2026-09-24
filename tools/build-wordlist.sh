#!/usr/bin/env bash
# Regenerates Sources/MenuType/Words.swift from a frequency-ranked corpus.
#
#   ./tools/build-wordlist.sh            # reuse a cached count_1w.txt if present
#   ./tools/build-wordlist.sh --fetch    # re-download the corpus first
#
# Source: Norvig's count_1w.txt (Google Web Trillion Word Corpus n-gram counts).
# Steps: regex/length/blocklist filter -> system spell-check -> Swift source.
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=".build/wordlist"
mkdir -p "$WORK"

CORPUS="$WORK/count_1w.txt"
if [[ "${1:-}" == "--fetch" || ! -f "$CORPUS" ]]; then
    echo "==> Downloading frequency corpus"
    curl -sSL --max-time 120 -o "$CORPUS" https://norvig.com/ngrams/count_1w.txt
fi
echo "==> corpus: $(wc -l < "$CORPUS" | tr -d ' ') ranked words"

echo "==> Filtering (regex, length, 2-letter whitelist, profanity/slur/brand blocklists)"
python3 tools/filter_words.py "$CORPUS" "$WORK/candidates.txt"

echo "==> Validating against the system spell checker"
swiftc -O -o "$WORK/spellfilter" tools/spellfilter.swift
"$WORK/spellfilter" "$WORK/candidates.txt" "$WORK/approved.txt"

echo "==> Generating Swift source"
python3 tools/generate_swift.py "$WORK/approved.txt" Sources/MenuType/Words.swift

echo "==> Auditing the result"
python3 tools/audit_words.py Sources/MenuType/Words.swift

echo
echo "Done. Rebuild with ./build.sh"
