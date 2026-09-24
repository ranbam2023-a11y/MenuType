#!/usr/bin/env python3
"""Audit the generated word corpus. Exits non-zero if anything looks rude.

Usage: audit_words.py Sources/MenuType/Words.swift

Two checks:

1. Exact match against the filter's blocklist, so a word that slipped past the
   pipeline for any reason still fails here.
2. A broad *substring* scan. This is the one that matters: it catches
   inflections and variants that an exact-match list misses. I originally lost
   `cunt`/`dick`/`cock`/`pussy`/`nazi` by rewriting the blocklist, and only a
   substring scan caught it. Every hit must appear in ALLOWED below, so any new
   hit fails the build and forces a human decision.
"""
import re
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from filter_words import BLOCKED  # noqa: E402

# Substrings worth flagging. Deliberately over-broad: false positives are fine,
# they just have to be listed in ALLOWED.
RISKY = """
fuck shitt cunt cock dick puss nigg fagg rape porn anal penis vagin orgasm eroti semen slut
whore nazi swast dyke kike spic coon retard tranny dildo incest bondage urine feces poop fart
puke molest pedo junkie heroin cocaine marijuana cannabis opium methamphet vomit diarrhea
herpes syphilis gonorrhea crap piss bitch sodom bestial fetish hooker erection viagra twat
bugger wanker bollock douche goddamn blowjob handjob boob nude naked shemale hentai milf
asshole arsehole dumbass jackass bastard clitor rectum scrotum testicl arousal upskirt
transsex transex
""".split()

# Words that legitimately contain a risky substring. Reviewed by hand; anything
# not in this list fails the audit.
ALLOWED = set("""
analysis analyst analog analyses analyze canal analytical analysts analyzed analyzing analyzer analytics
scrap scrapbook scrape scraps
grape
spice spicy
cocktail
homosexual bisexual sophomore
basement amusement
figurines
""".split())


def corpus_words(path: str) -> list[str]:
    src = open(path).read()
    marker = "private static let chunks: [String] = ["
    if marker not in src:
        raise SystemExit(f"{path}: can't find corpus chunks — is this the generated file?")
    body = src.split(marker, 1)[1]
    return " ".join(re.findall(r'"([^"]*)"', body)).split()


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "Sources/MenuType/Words.swift"
    words = corpus_words(path)
    if not words:
        raise SystemExit(f"{path}: corpus is empty")
    if len(words) != len(set(words)):
        raise SystemExit(f"{path}: corpus has duplicates")

    failures = []

    exact = sorted({w for w in words if w in BLOCKED})
    if exact:
        failures.append(f"blocklisted words present: {' '.join(exact)}")

    unlisted: dict[str, list[str]] = {}
    for word in words:
        for risk in RISKY:
            if risk in word and word not in ALLOWED:
                unlisted.setdefault(risk, []).append(word)
    if unlisted:
        for risk in sorted(unlisted):
            failures.append(f"'{risk}' in unlisted word(s): {' '.join(sorted(set(unlisted[risk])))}")

    if failures:
        print(f"FAIL — {path} ({len(words)} words)")
        for f in failures:
            print(f"  * {f}")
        print("\nEither add the word to EXPLICIT in filter_words.py, or add it to")
        print("ALLOWED in audit_words.py if it is a false positive like 'analysis'.")
        return 1

    print(f"  audit passed: {len(words)} words, no profanity, slurs, sexual or crude content")
    return 0


if __name__ == "__main__":
    sys.exit(main())
