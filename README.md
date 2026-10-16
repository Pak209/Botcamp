# Botcamp: Learn AI (iOS, v0.2)

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
`scripts/build-course.mjs` converts `../get-up-to-speed/content.js` + every `content/*.overlay.json` into `Botcamp/Resources/course.json` (data only, guideline 2.5.2 friendly):
```bash
node scripts/build-course.mjs [path/to/content.js]
```
All 10 units are fully authored (50 lessons). Units 4–10 are Pro-gated. Facts come only from content.js / PLAN.md (checked Oct 14, 2026).

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

## v0.2 features
- **Onboarding:** Sarge Byte intro → goal → daily goal (+ optional reminder).
- **Review mode:** every first-time miss is saved (`MissedQuestion`); the Learn tab shows a Review card (up to 10 per session). Right on the first try clears it.
- **Daily-goal reminders:** opt-in, local `UNUserNotificationCenter` only; permission is asked only when you turn it on. Skips today if the goal is met.
- **Plan tab:** native port of the web capstone advisor (`BotcampCore/Advisor.swift`), with links back to units.
- **Certificate:** unlocked when all 50 lessons are done; rendered with `ImageRenderer` and shared via `ShareLink`.
- **Mascot moments:** level-up burst on rank-up, flickering streak flame, animated XP/daily-goal bars, sleeping Sarge with Zzz on a broken streak (`Views/MascotMoments.swift`).

## Not done yet
First Xcode build on a Mac (UI code is syntax-checked only), TestFlight / App Store Connect product, privacy/support pages, store listing. Re-check Apple guidelines and model facts before submitting.
