# Botcamp: Learn AI (iOS, v0.1 MVP)

Duolingo-style SwiftUI app that teaches AI from zero. Mascot: **Sarge Byte**.
Plan: `get-up-to-speed/APP-PLAN.md`. Pricing: Units 1–3 free; **Pro** is a one-time ~$4.99 StoreKit 2 unlock (placeholder product `com.pak209.botcamp.pro`). Lifetime tier comes later.

## Build on a Mac
```bash
brew install xcodegen
xcodegen generate          # creates Botcamp.xcodeproj
open Botcamp.xcodeproj     # set your Team under Signing & Capabilities, run on iOS 17+ simulator
swift test                 # runs BotcampCore unit tests (no simulator needed)
```
The Botcamp scheme uses `Botcamp/Botcamp.storekit`, so the Pro purchase works locally without App Store Connect.

## Content pipeline
`scripts/build-course.mjs` converts `../get-up-to-speed/content.js` + `content/units-1-3.overlay.json` into `Botcamp/Resources/course.json` (data only, guideline 2.5.2 friendly):
```bash
node scripts/build-course.mjs [path/to/content.js]
```
Units 1–3 are fully authored. Units 4–10 are stubs (one preview card each, Pro-gated).

## Layout
| Path | What |
|---|---|
| `Sources/BotcampCore/` | Platform-independent: course model + decoding/validation, grading, XP/streak/rank rules, path unlocking, AI app hand-off targets |
| `Tests/BotcampCoreTests/` | Content parsing + progression tests (`swift test`) |
| `Botcamp/App/` | App entry, CourseStore, SwiftData models (`PlayerProfile`, `LessonRecord`), StoreKit 2 `ProStore` |
| `Botcamp/Views/` | Home path map, lesson player + 9 step types, Copy & open hand-off, glossary, paywall, profile/ranks |
| `Botcamp/Resources/` | `course.json`, asset catalog (mascot poses, rank badges, brand colors, app icon) |

## Lesson types
explain · choice · true/false · multi-select (unit checks) · spot the better prompt · fix the prompt · match · order the steps · **hand-off** (copy prompt → open Grok/ChatGPT/Claude or its website → return → self-check list).

Missed questions come back at the end of a lesson (no hearts). Unit checks need 70% first-try correct.
Streaks: one lesson/day; a freeze is earned every 7 days (max 2).

## Not done yet
TestFlight / App Store Connect product, onboarding, daily-goal reminders, review mode, certificate, capstone planner, Units 4–10 content. Re-check Apple guidelines and model facts before submitting.
