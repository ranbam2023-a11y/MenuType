# MenuType

A macOS menu bar typing trainer — *menu-bar monkeytype*. A random word lives in
your menu bar and fills in **as you type**. Click it for speed and accuracy.

```
menu bar:  ● c u r v e      ← typed "cur", cursor on "v", rest dimmed
           ● c u r v e ✓    ← finished — press space for the next one
```

*(The name is the pun: menu + type, with a nod to Monotype the type foundry and
to Monkeytype the trainer.)*

## Offline

Yes, completely. No `URLSession`, no `CFNetwork`, no `nw_*` symbols, no network
framework linked and no network entitlements — the words ship inside the binary
and stats go to `UserDefaults`. You can verify:

```bash
otool -L MenuType.app/Contents/MacOS/MenuType | grep -iE 'network|cfnetwork'   # nothing
nm -u MenuType.app/Contents/MacOS/MenuType | grep -ciE 'URLSession|CFNetwork|socket'  # 0
```

## Install

Grab `MenuType-1.0.0.dmg` from the [latest
release](https://github.com/ranbam2023-a11y/MenuType/releases/latest), open it,
and drag **MenuType** onto **Applications**. macOS 13 or later.

The app is **ad-hoc signed, not notarised**, so Gatekeeper blocks the first
launch. Right-click the app and pick **Open**, then confirm — or:

```sh
xattr -d com.apple.quarantine /Applications/MenuType.app
```

There is no Dock icon and no window: MenuType lives in the menu bar. Quit from
the panel's **Quit** button, or `pkill -x MenuType`.

## Build from source

```bash
./build.sh          # release build + MenuType.app bundle + icon + ad-hoc sign
./make-dmg.sh       # the above, then package MenuType-1.0.0.dmg
open MenuType.app
```

## The panel

```
MenuType                       In app ⬤ Everywhere     ← compact header + mode switch
┌──────────────────────────────────────────────┐
│ │   e q       u i p m e n t   clu            │        ← tape, letter mode
└──────────────────────────────────────────────┘
┌────────┐ ┌──────────┐ ┌──────────────┐
│ 96     │ │ 100%     │ │ 8            │                ← WPM · accuracy · words today
│ WPM    │ │ ACCURACY │ │ WORDS TODAY  │
└────────┘ └──────────┘ └──────────────┘
▸ Stats              best 74 wpm
▸ Previous words     8
▸ Settings           english 1k                        ← collapsed by default
New word                        Reset stats · Quit
space next word · ⌫ fix typo · esc skip
```

**Settings** holds the word pool and the appearance (`Auto` / `Light` / `Dark`,
persisted). The pool control is a `Menu` rather than a `Picker` because the
native popup button draws its own light bezel that fights the panel; this one is
filled with the panel background so it blends in.

**Tape mode — letter, not word.** This is monkeytype's `tapeMode: "letter"`:
the offset is `words before the current one + the width of the letters you've
already typed`, so the tape scrolls one *character* at a time and the caret stays
put on the letter you're about to type. Typed letters scroll past the caret and
fade out at the left edge; the caret sits at `marginPercent` (monkeytype's
`tapeMargin`, though theirs defaults to 50% of a full-width page — at 302pt that
would leave barely one word visible, so this is tuned to ~22% to keep about
three words in view). Word widths are computed from character counts rather than
measured, using the same `NSFont` for the maths and the text, so the slide stays
exactly aligned.

**Word pool.** `english 50 / 200 / 500 / 1k / 5k / 10k` in Settings. Each tier is
a prefix of one frequency-ranked list, so `english 50` really is the 50 most
common words and larger tiers widen outward. The choice persists.

**Stats**, **Previous words** and **Settings** are collapsed dropdowns to keep
the panel small.

**Light and dark mode.** Colours are dynamic `NSColor`s, so the system swaps
them; the controller sets the popover view's appearance as well as
`preferredColorScheme`, because dynamic colours resolve against the *view's*
effective appearance and the panel would otherwise render dark while claiming to
be light.

## Where the words come from

`/usr/share/dict/words` can't do tiers: it's *alphabetical* (`a, aa, aal,
aalii…`), full of proper nouns, and it's a 1934 dictionary that predates
"internet", "email" and "software". A "50" tier taken from it would be
meaningless. So the corpus ships inline — the ~66KB it costs is worth it, and
you can regenerate it:

```bash
./tools/build-wordlist.sh          # add --fetch to re-download the corpus
```

Pipeline (see `tools/`):

1. **`filter_words.py`** — takes Norvig's `count_1w.txt` (Google Web Trillion
   Word Corpus frequency counts) and keeps lowercase a-z words of 2–10 letters.
   2-letter words must be real words, otherwise they're state/country codes.
   Blocklists drop profanity, slurs, sexual and anatomical content, drug slang,
   brand names, acronyms, file extensions and web-corpus chrome (`page`, `site`,
   `search`, `pm`, `usa`, `php`…).
2. **`spellfilter.swift`** — validates each survivor against the system spell
   checker, which removes typos, foreign tokens and leftovers like `verzeichnis`
   and `ebay` while keeping modern words like `internet` and `email`.
3. **`generate_swift.py`** — emits `Sources/MenuType/Words.swift`.
4. **`audit_words.py`** — **fails the build** if anything rude got through.

Step 4 matters more than it sounds. The audit does an exact-match pass *and* a
deliberately over-broad **substring** pass where every hit must be a
hand-reviewed false positive. I lost `cunt`, `dick`, `cock`, `pussy` and `nazi`
by rewriting the blocklist, and only the substring scan caught it.

Content policy: profanity, slurs, sexual/anatomical content and drug slang are
out. Ordinary vocabulary on unpleasant topics (`kill`, `gun`, `death`, `ugly`)
and neutral descriptors stay in, because stripping those would distort a
frequency list. Adjust `EXPLICIT` in `tools/filter_words.py` and re-run.

## Modes

The switch in the header flips between the two:

**In app** (default) — words fill in only while the panel is open. No
permissions needed. Every keystroke counts immediately, typos included.

**Everywhere** — keystrokes are captured system-wide, so you can play without
opening the panel. Needs **Accessibility** permission (macOS prompts and opens
the right System Settings pane; grant it, then flip the switch again). It
auto-offs after 60 seconds with no keystrokes.

## Why a stray word never turns red

If the app is listening system-wide, ordinary typing in other apps would
otherwise be scored as errors and paint the menu bar red. So in everywhere mode
a word sits **asleep** until it's sure you're playing it:

1. **Asleep** — keystrokes are ignored entirely unless they continue the word's
   spelling, one character at a time. A wrong key is not recorded, not shown
   red, and not counted against accuracy. Backspace and space do nothing, and
   the menu bar shows no cursor, so asleep is visually obvious.
2. **Awake** — once your typed prefix matches the first two characters
   (`commitThreshold`), it's clearly deliberate: the cursor appears, the clock
   starts from the first matched character, and from then on every keystroke
   counts, typos included.
3. **Back asleep** — stop typing for 2.5 seconds (`disengageAfter`) and the word
   resets and goes back to sleep. A half-typed or red word never lingers.

Closing the panel also clears partial progress, so leftover typing can't show up
as a red word afterwards.

## Keyboard

| Key | Action |
| --- | --- |
| letters | type the word (case-insensitive) |
| `space` | **next word** — the only way forward once a word is finished |
| `⌫` | fix a typo (not once the word is complete) |
| `esc` / `return` / `tab` | skip to a new word |
| `space` before typing | skip the untouched word |

Letters are ignored once a word is complete, so you always press space to move
on. Shortcuts with `⌘`, `⌃` or `⌥` are never intercepted, key-repeat is ignored,
and non-letters pass straight through.

## Stats

WPM uses the standard `correct characters ÷ 5` per minute. Accuracy is measured
on **raw keystrokes**, so fixing a typo still costs you — same as monkeytype.
A word only counts toward your streak if you typed it with no mistakes.

**Best WPM is measured over a rolling five-word window**, not a single word:
`total correct characters over total time` for the last five words. One short
word typed quickly produces an absurd one-word WPM, so a window is what "best"
should mean. Average WPM is the same calculation over ten words. Best stays at
`—` until five words exist. Existing per-word bests are not trusted — the stats
key moved to `v2` and best is recomputed from whole windows on load.

## Layout

```
Sources/MenuType/
  main.swift             NSApplication bootstrap (accessory app, no Dock icon)
  AppDelegate.swift      owns the StatusController
  StatusController.swift status item, menu bar rendering, popover, key monitors
  TypingEngine.swift     tape, typing state machine, sleep/wake, metrics
  StatsStore.swift       persisted all-time/recent/daily stats
  Appearance.swift       Auto / Light / Dark
  Palette.swift          dynamic colours, resolved per appearance
  TapeView.swift         the tape, its layout maths, and letter-mode offset
  PopoverView.swift      SwiftUI panel (metrics + dropdowns)
  Words.swift            GENERATED word corpus and tiers
tools/                   corpus build pipeline + audit
```

Both input paths feed the same `TypingEngine`: a **local** `NSEvent` monitor for
panel typing (no permissions) and a **global** monitor for everywhere mode
(called out to only when the panel is closed, so nothing is double-counted).
Only the global path uses the sleep/wake rules.

## Notes

- Built with SPM; needs only the CommandLineTools toolchain. Because that SDK
  can't load SwiftUI's `@State` macro plugin, panel-local state uses a small
  `ObservableObject` instead.
- The `.app` is ad-hoc signed. If you rebuild, macOS may ask for Accessibility
  permission again since the binary changed.
- Nothing is sent anywhere; keystrokes are only used to score the current word
  and are not logged.
