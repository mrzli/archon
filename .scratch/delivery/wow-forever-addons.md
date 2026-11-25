# WoW Forever add-ons delivery queue

User branch: `forever-loot-sparkles`. The user approved merging it into `master` once all items are integrated and reviewed.

## 1. Pin InteractGlow for WoW Forever

- **Decision:** add the CurseForge-only InteractGlow add-on to `components/wow-setup/setup.sh` as a pinned Forever-only add-on, installed through `install-pinned-addon.sh` like Forever Loot Sparkles. Pin: folder `InteractGlow`, version `0.2.1` (the TOC's `## Version`; CurseForge labels the file "v1.0"), URL `https://edge.forgecdn.net/files/9072/814/InteractGlow%20%283%29.zip` (CurseForge file 9072814), SHA-256 `ba3889b0ccf62d9d2fd509aed9231eda1f56d72176350883b85cce4f4b1251a8`. The archive holds only `InteractGlow/`, TOC `## Interface: 16001`. Add it to the header comment's list of pins to check (`https://www.curseforge.com/wow/addons/interactglow/files`) and to the help text. Extend `components/wow-setup/tests/setup_test.rb`: fixture archive, install message, present in Forever, absent in Retail. Small change in one unit: background fork of the main session.
- **Footprint:** `components/wow-setup/setup.sh`, `components/wow-setup/tests/setup_test.rb`.
- **Depends on:** none.
- **Status:** integrated.
- **Commits:** 2ade83f.
- **Times:** started 2026-11-25 23:05, integrated 2026-11-25 about 23:08 (about 3 min); implementer run 69 s, review 43 s.
- **Measurements:** fork on the session model; no restarts; first run of the required checks passed; review: 0 blocking, 0 major, 2 minor (add-on behavior notes for the user, no code change), 1 nit (header comment wrap, fixed in item 2); 0 fix rounds.

## 2. Match pinned test downloads by exact URL

- **Decision:** in `components/wow-setup/tests/setup_test.rb`, the curl stub stops guessing a fixture archive by a folder name contained in the URL. The fixture reads each pin's exact URL from `setup.sh`, the way `pinned_sha` reads its checksum, and passes a URL-to-archive map to the stub, which aborts on an unknown URL. The `run_pinned` helper's `https://example.invalid/<folder>.zip` URLs must map too. Test-only change; behavior of `setup.sh` is unchanged. Contained change in one unit: background fork of the main session.
Also reflow the header comment of `components/wow-setup/setup.sh` so `# Check` does not stand alone on its line (nit from item 1's review).
- **Footprint:** `components/wow-setup/tests/setup_test.rb`, the header comment of `components/wow-setup/setup.sh`.
- **Depends on:** 1 (same test file), integrated.
- **Status:** integrated.
- **Commits:** 40782f0, df01e0f, 04b5df4 (review fix).
- **Times:** started 2026-11-25 about 23:08, integrated about 23:14 (about 6 min); implementer run 125 s, review 36 s.
- **Measurements:** fork on the session model; no restarts; first run of the required checks passed; review: 0 blocking, 0 major, 1 minor (comment line length, fixed in the main session as suggested), 0 nits; 1 fix round.
