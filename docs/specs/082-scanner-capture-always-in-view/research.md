# Spec 082: the sitting at the full framing (2026-11-13)

**What this is.** A hand reconstruction of one unpaired pass at the full framing, not a measured run as filed, and not a test of any bar. The maintainer withdrew the paired comparison after the sitting (spec 082 1.1.0, decision 4): there is no shipped-framing pass, bar A is not applied, the full framing ships as built, and reading accuracy at the new framing is left to later scanner stories. Nothing below is called a pass.

## The sitting

- **Corpus:** 40 cards the maintainer owns, `~/card-scanner-corpus/phase082/manifest.csv` (C001 to C040; outside the repository), 20 sets. Every row resolved to exactly one English printing (`scanner:ground_truth`: 40 resolved, 0 errors). 8 frames print no set code (pre-M15: `ths`, `isd`, `jou`, `cns`, C032 to C039) and are left out of the exact-printing rate; 32 print one.
- **Short of decision 4's mix:** 5 foils, not 8 (C027 to C031), by the maintainer's ruling of 2026-11-13. C029 Way of the Mentor (`fra` 208, foil) is spec 007's tuning card T011, kept by the maintainer's ruling and scored both ways below (`scanner:overlap` aborts on it, as expected).
- **Conditions:** iPhone, Brave (WebKit; the user agent reports Version/27.2), over HTTPS on the LAN; the full framing (stage 402 × 501 px, video 1080 × 1920); art matching off, so every rank below is the text-only ranking; recognition median 149 ms. One pass in manifest order, 17:29 to 17:52 local time, not in ABBA blocks.
- **Captures:** 66 for 40 cards. The maintainer retook several cards and one never read: C039 Demolish, 19 attempts.

## Why the run as filed is meaningless (13/40)

Scored by the rows the captures were filed under, the run reads right card first 13/40 and exact printing 12/32. That is an artefact of measurement mode, not of the reading:

- After a capture, the run moves to the next pending row. A retake taken from the camera (Scan again, Capture) without choosing the row in the run sheet is filed as the **next card's** measured capture, and every later card shifts by one. C014 was captured three times, C028 twice and C035 three times in place, so from C015 on each row holds an earlier card (C022's row holds C020's card; C032's holds C029's).
- Once every row has a capture, the row select falls back to its first option, so the 26 captures after the 40th were all filed as retakes of C001. They are C036 (2 captures), C037 (2), C038 (2), C039 (19) and C040 (1).

Both are filed as issue [#419](https://github.com/plainprogrammer/Collector/issues/419) (measurement mode, development only; not fixed on this branch).

**My first diagnosis was wrong.** I first read the 26 C001 captures as more attempts at C001, Celestial Unicorn, from the artist name "Volkan Baga" repeating in their collector strips. Celestial Unicorn's artist is Justine Mara Andersen (its one capture says so); Volkan Baga painted C039 Demolish. Scoring by row then gave 13/40, and the misses' strips showed cards two and three rows earlier than their rows (C022's capture reads "FRA 0169", C020's card), which is what led to the reconstruction.

## The reconstruction

Each capture was paired with the card in hand from the capture order and what its strips show: set codes and collector numbers, names, artists and copyright years (2011 for `isd`, 2014 for `jou`). Each card's first capture in that order is the one scored. 37 pairings are certain. Three are by position: the first captures of C037 Trumpet Blast, C038 Minotaur Skullcleaver and C039 Demolish (captures 43, 45 and 47) read nothing identifiable. The working, every capture with its row, card and evidence, is in [`research-captures.md`](research-captures.md). The scoring is `Collector::ScannerFindings.rescore` over those first captures against the ground truth (the same scorer the findings tasks use).

## Figures, side by side

None of these is the result, and no bar is applied.

| Set | Right card first | Top 3 | Exact printing (set-line cards) | Foils | Non-foils | Name read |
|---|---|---|---|---|---|---|
| All 40 | 34/40 (85.0%) | 34/40 | 29/32 (90.6%) | 4/5 | 25/27 | 5/40 |
| 39 without C029 (the tuning card) | 33/39 (84.6%) | 33/39 | 28/31 (90.3%) | 3/4 | 25/27 | 5/39 |
| 37 with certain pairings (without C037 to C039) | 34/37 (91.9%) | 34/37 | 29/32 (90.6%) | 4/5 | 25/27 | 5/37 |

Not right card first (strips looked at for each):

- **C014 Harnessed Lightning** (`kld` 117): the collector line read "17/264 U KLD", a digit dropped; with no strong name match the one-digit correction did not apply, and the first candidate was Glint-Sleeve Artisan (`kld` 17). Its third capture read 117.
- **C035 Slayer of the Wicked** (`isd` 32), **C036 Bladetusk Boar** (`jou` 90), **C037 Trumpet Blast** (`cns` 154), **C038 Minotaur Skullcleaver** (`ths` 130), **C039 Demolish** (`ths` 118): all pre-M15 frames with no set code, so only the name can match, and none was read on the first capture (C038's matched a wrong card). Retakes named C035, C036 and C038; C039 never read in 19 tries.

Without the exact printing: C002 Concordia Pegasus (the line read "M21 + EN" with no number), C014 (above), C028 Cleric Class (its first line read 068 for 006).

## What later scanner stories might look at

An observation from one pass, not a measured rate:

- **Frames with no set code depend on the name strip alone.** Five of the eight pre-M15 frames missed on the first capture with art matching off, and one never read. Art matching, or a better read of old name bars, is where these would come from.
- **A dropped digit with no strong name.** C014's "17" for "117" found the wrong printing; the one-digit correction runs only after a strong name match.

## What this does not show

- No comparison with the shipped framing: there was no shipped pass.
- Not comparable with spec 011's 34/35 (art matching on, other cards) or spec 009's 31/35 text-only first captures (other cards, another phone, the 3:4 stage).
- One pass in manifest order, so order, light and handling are not balanced across anything.
- Three of the 40 first captures are paired by position.

## Owed, not done at the sitting

The screen-reader pass on a phone, the check that the frozen frame lines up with the live picture, and `script/scanner/detector_parity.rb` (it needs the spike corpus and a dev server) were not done; `verification.md` says so.
