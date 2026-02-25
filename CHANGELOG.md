# Changelog

All notable changes to this project will be documented in this file.

## 0.2.3 - 2026-02-25

Changed
- Quit key handling now supports `q` (in addition to `<Esc>`) across menu, rounds, and summary screens.
- Summary screen quit action was simplified by removing `(3) Close` in favor of `(q) Quit`.

## 0.2.2 - 2026-01-29

Changed
- Title is now on the window header

## 0.2.1 - 2026-01-22

Changed
- End of session screen allows to start a new one (or quit)

## 0.2.0 - 2026-01-16

Changed
- Scoring now awards attempt-based points per round and reports accuracy.

## 0.1.1 - 2026-01-15

Changed
- Default rounds set to 10.
- Default hint-on-miss setting set to false.

## 0.1.0 - 2026-01-15

Added
- `:NumRow` command to launch the game.
- Floating window UI with a simple mode picker.
- Symbol locator rounds with scoring, misses, and optional hints.
- Config options for rounds, feedback style, symbols/digits, and window layout.
