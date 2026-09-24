#!/usr/bin/env python3
"""Turn the frequency-ranked corpus + spell-check verdicts into Sources/MenuType/Words.swift.

Pipeline (see build-wordlist.sh):
  1. filter_words.py   count_1w.txt  -> candidates.txt   (regex, length, blocklists)
  2. spellfilter.swift candidates.txt -> approved.txt    (system spell checker)
  3. generate_swift.py approved.txt  -> Sources/MenuType/Words.swift

Usage: python3 generate_swift.py approved.txt Sources/MenuType/Words.swift [tier_max]
"""
import sys

TIER_MAX = 10000


def main() -> int:
    src_path = sys.argv[1] if len(sys.argv) > 1 else "approved.txt"
    out_path = sys.argv[2] if len(sys.argv) > 2 else "Sources/MenuType/Words.swift"
    tier_max = int(sys.argv[3]) if len(sys.argv) > 3 else TIER_MAX

    words = [w for w in open(src_path).read().split("\n") if w]
    final = words[:tier_max]
    if len(final) < tier_max:
        raise SystemExit(f"only {len(final)} words available, need {tier_max}")

    chunks = [" ".join(final[i:i + 1000]) for i in range(0, len(final), 1000)]
    body = "\n".join(f'        "{c}",' for c in chunks)

    src = f'''import Foundation

/// Difficulty tiers, mirroring monkeytype's english lists.
///
/// Each tier is a prefix of one frequency-ranked corpus, so `english 50` really
/// is the 50 most common words and `english 10k` widens outward from there.
enum WordList: String, CaseIterable, Identifiable, Codable {{
    case english50
    case english200
    case english500
    case english1k
    case english5k
    case english10k

    var id: String {{ rawValue }}

    var title: String {{
        switch self {{
        case .english50: return "english 50"
        case .english200: return "english 200"
        case .english500: return "english 500"
        case .english1k: return "english 1k"
        case .english5k: return "english 5k"
        case .english10k: return "english 10k"
        }}
    }}

    var count: Int {{
        switch self {{
        case .english50: return 50
        case .english200: return 200
        case .english500: return 500
        case .english1k: return 1000
        case .english5k: return 5000
        case .english10k: return 10000
        }}
    }}
}}

/// The word pool.
///
/// GENERATED FILE — edit `tools/` and re-run `tools/build-wordlist.sh`.
///
/// The corpus is frequency-ranked ({tier_max} most common English words),
/// filtered to 2-10 letters, validated against the system spell checker, and
/// scrubbed of profanity, slurs, sexual and anatomical content, drug slang,
/// brand names and web-corpus noise.
///
/// It ships inline because nothing on the system can rank words by frequency:
/// `/usr/share/dict/words` is alphabetical, so a "50" tier taken from it would
/// just be `a, aa, aal, aalii...`, and it is a 1934 dictionary that predates
/// "internet", "email" and "software".
enum Words {{
    static let corpus: [String] = chunks
        .joined(separator: " ")
        .split(separator: " ")
        .map(String.init)

    /// A random word from the chosen tier, avoiding repeats where it can.
    static func random(for list: WordList, avoiding: Set<String> = []) -> String {{
        guard !corpus.isEmpty else {{ return "word" }}
        let limit = min(list.count, corpus.count)
        guard limit > 1 else {{ return corpus[0] }}
        for _ in 0..<24 {{
            let word = corpus[Int.random(in: 0..<limit)]
            if !avoiding.contains(word) {{ return word }}
        }}
        return corpus[Int.random(in: 0..<limit)]
    }}

    /// A fresh queue, with no repeats inside it.
    static func randomQueue(count: Int, from list: WordList) -> [String] {{
        var words: [String] = []
        for _ in 0..<max(1, count) {{
            words.append(random(for: list, avoiding: Set(words)))
        }}
        return words
    }}

    /// 1,000 words per literal, so no single literal is enormous.
    private static let chunks: [String] = [
{body}
    ]
}}
'''
    with open(out_path, "w") as f:
        f.write(src)
    print(f"wrote {out_path}: {len(final)} words in {len(chunks)} chunks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
