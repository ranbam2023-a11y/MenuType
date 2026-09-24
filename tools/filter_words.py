#!/usr/bin/env python3
"""Filter a frequency-ranked word list down to typing-practice candidates.

Usage: filter_words.py <count_1w.txt> <candidates.txt> [keep]

Rules applied, in order:
  * lowercase a-z only, 2-10 letters
  * 2-letter words must be real words (not US state / country codes)
  * profanity, slurs, sexual/anatomical content and drug slang are dropped
  * brand names, acronyms, file extensions, roman numerals, weekday and month
    abbreviations, and web-corpus noise are dropped
"""
import re
import sys

# Real 2-letter English words. Everything else 2-letter in a web corpus is a
# state code, country code or initialism (ca, ny, pm, uk, id, ...).
TWO_LETTER = set("am an as at be by do go he hi if in is it me my no of on or so to up us we".split())

# Acronyms, tech/web tokens, units, roman numerals, brand names, web chrome.
ACRONYM_AND_WEB = set("""
  usa uk eu un ussr gmt utc php xml sql rss pdf dvd cds lcd css ftp http www com org net
  gov edu url html htm gps pda psp nfl nba mlb nhl abc cbs nbc bbc cnn cnet ibm hp pc mac os
  mb gb kb tb mhz ghz dpi ram rom cpu usb dsl faq faqs pm am est pdt pst cet btw aka diy iso
  api sdk uri uml gui oem vpn lan wan tcp ip udp dns hdd ssd gpu mbps bps
  ii iii iv vi vii viii ix xi xii xiii xiv xv xvi xix xx xxi
  jan feb mar apr jun jul aug sep sept oct nov dec mon tue tues wed thu thur thurs fri sat sun
  tv cd dj ids gif jpg jpeg png bmp mp3 mp4 wav avi divx dvdr cdrom hd hdtv led
  usd eur jpy aud cad chf
  nokia sony dell samsung motorola panasonic toshiba ericsson siemens philips kodak canon nikon
  google yahoo amazon ebay adobe microsoft apple intel cisco oracle netscape aol msn icq skype
  levitra cialis paxil zoloft prozac xanax valium ambien
  gratis verzeichnis webmaster sitemap permalink trackback weblog blog blogger spam spyware
  page site search web click online contact privacy copyright download info services business
  homepage website login logout signup signin subscribe newsletter disclaimer terms
  javascript browser server hosting domain domains
  comp alt proc autos pid vous seagate
""".split())

# Profanity, slurs, sexual/anatomical content, drug slang, crude insults.
# Neutral words on unpleasant topics (kill, gun, death, stupid, ugly) are kept.
EXPLICIT = set("""
  fuck fucked fucking fucker fuckers fuckin motherfucker
  shit shitty bullshit crap crappy craps piss pissed pissing pisser
  bastard bastards bitch bitches asshole assholes arse arsehole bugger bollocks bollock
  wanker tosser prick twat bloody damn goddamn hell
  cunt cunts dick dicks cock cocks douche slutty
  ass asses arse
  nigger niggers nigga faggot faggots fag fags dyke dykes chink chinks kike kikes spic spics
  wetback gook gooks raghead towelhead paki pakis coon coons darkie sambo
  retard retards retarded mong spastic spaz cripple cripples midget tranny trannies shemale
  queer queers homo homos sodomite sodomy
  nazi nazis hitler fascist
  sex sexo sexy sexual sexualities sexuality sexually porn porno pornos pornstar nude nudes naked nudity
  pussy pussies boob boobs booby tit tits titty titties busty cleavage penis penises
  vagina vaginas vaginal vulva
  clitoris scrotum testicle testicles anus rectum
  dildo dildos orgasm orgasms orgasmic erotic erotica horny milf milfs hentai upskirt xxx
  bondage blowjob blowjobs handjob handjobs cum semen anal transexual transsexual erection erections
  prostitute prostitutes prostitution whore whores slut sluts hooker hookers brothel brothels
  stripper strippers escort escorts vibrator vibrators masturbate masturbation orgy orgies
  incest rape raped raping rapist rapists molest molested molester pedophile paedophile
  bestiality beastiality necrophilia fetish fetishes nymph nympho erectile
  cocaine heroin marijuana cannabis opium methamphetamine meth amphetamine ecstasy lsd morphine
  narcotic narcotics junkie
  vomit vomited feces urine urinate defecate diarrhea poop fart farts farting puke phlegm mucus
  snot spit spitting booger boogers constipation burp burps belch
  idiot idiots moron morons imbecile imbeciles dumb dumber dumbest dumbass jackass badass halfass
  stupid stupidity lame moronic
  herpes syphilis gonorrhea chlamydia
  middlesex viagra
""".split())

BLOCKED = ACRONYM_AND_WEB | EXPLICIT


def is_candidate(word: str) -> bool:
    if not re.fullmatch(r"[a-z]+", word):
        return False
    n = len(word)
    if n < 2 or n > 10:
        return False
    if n == 2 and word not in TWO_LETTER:
        return False
    return word not in BLOCKED


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 else "count_1w.txt"
    dst = sys.argv[2] if len(sys.argv) > 2 else "candidates.txt"
    keep = int(sys.argv[3]) if len(sys.argv) > 3 else 40000

    seen = set()
    out = []
    with open(src, encoding="utf-8", errors="ignore") as f:
        for line in f:
            parts = line.split()
            if len(parts) < 2:
                continue
            word = parts[0].lower()
            if word in seen:
                continue
            seen.add(word)
            if is_candidate(word):
                out.append(word)
    with open(dst, "w") as f:
        f.write("\n".join(out[:keep]))
    print(f"  {len(out)} candidates pass the blocklists, keeping {min(keep, len(out))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
