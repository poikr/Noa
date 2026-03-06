# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Noa is an Apple Watch school timetable app. Users enter their weekly schedule on the iPhone app, which syncs to Apple Watch via WatchConnectivity. The watch displays current class status, countdown timers, and watchface complications.

## Build & Run

This is an Xcode 26 project (Swift 6.2). Open `Noa.xcodeproj` in Xcode and build.
- **iOS app**: Select "Noa" scheme, target iPhone simulator/device
- **Watch app**: Select "Noa" scheme (Watch app is embedded), target paired Apple Watch
- **Widget**: Automatically built with Watch app (NoaWidgetExtension target)

No package managers (SPM/CocoaPods) are used. No test targets exist.

## Architecture

### Targets & Shared Code

4 targets sharing code via `PBXFileSystemSynchronizedRootGroup`:

| Target | Platform | Directory |
|--------|----------|-----------|
| Noa (iOS) | iOS 26+ | `Noa/` |
| Noa Watch App | watchOS 26+ | `Noa Watch App/` |
| NoaWidgetExtension | watchOS 26+ | `NoaWidget/` |
| (shared) | all 3 targets | `Shared/` |

The `Shared/` folder is referenced by all 3 targets in the pbxproj. Adding files to `Shared/` makes them available everywhere automatically.

### Data Flow

```
iPhone (edit timetable)
  → TimetableStore (save to App Group UserDefaults: group.kr.poi.Noa)
  → ConnectivityManager (WCSession.updateApplicationContext + sendMessageData)
  → Watch TimetableStore (receives & saves)
  → Widget reads directly from App Group UserDefaults via TimetableStore.loadFromDefaults()
```

### Key Shared Components

- **Models.swift**: `Weekday`, `PeriodTime`, `ClassEntry`, `Timetable` — all `Codable`, `Sendable` value types
- **ScheduleEngine.swift**: Pure function `currentState(for:timetable:)` returns `ScheduleState` enum (inClass, breakTime, beforeSchool, afterSchool, weekend, noClass). This is the core logic used by Watch app, Widget, and complications.
- **TimetableStore.swift**: `@Observable` singleton using App Group UserDefaults. Widget uses `loadFromDefaults()` (nonisolated static method) instead of the singleton.
- **ConnectivityManager.swift**: `WCSessionDelegate` with `nonisolated` delegate methods dispatching to `@MainActor` via `Task`.
- **NotificationManager.swift**: Schedules `UNCalendarNotificationTrigger` weekly repeating notifications.

### JSON Backward Compatibility

All model types use custom `init(from decoder:)` with `decodeIfPresent` for fields added after v1. When adding new fields to `Codable` models, always use `decodeIfPresent` with a sensible default so that JSON from older versions still decodes. Currently optional fields:
- `PeriodTime.name` (default: `""`)
- `ClassEntry.isFood` (default: `false`)
- `Timetable.extraSchedules` (default: `[]`)
- `Timetable.arrivalHour` / `arrivalMinute` (default: `8` / `30`)

### Swift Concurrency Notes

The project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`. All types are `@MainActor` by default. WCSessionDelegate methods must be explicitly `nonisolated`.

### Widget Complications

`NoaWidget.swift` provides 4 watchface styles: `accessoryCircular`, `accessoryRectangular`, `accessoryInline`, `accessoryCorner`. Uses `Text(timerInterval:countsDown:)` for live second-by-second countdown when ≤ 3 minutes remain. Timeline generates entries at 1-minute intervals plus key transition points (period start/end, 3-min warnings).

### Color Convention

- **Green**: in class / active
- **Orange**: break time
- **Red**: ≤ 3 minutes remaining (urgency) or END badge
- Colors determined by `urgencyColor(remaining:normal:)` helper

### Slot Key Convention

Timetable slots are stored as a `[String: ClassEntry]` dictionary with keys formatted as `"{weekday.rawValue}_{periodIndex}"` (e.g., `"2_0"` = Monday period 0). Weekday raw values follow `Calendar.component(.weekday)`: Monday=2 through Friday=6.

### ScheduleEngine Slot Merging

`ScheduleEngine.buildSlots()` merges regular class periods and extra schedules into a single sorted timeline. Extra schedules use `period: -1`. The engine uses seconds-of-day for all time comparisons. Before 4AM is treated as `afterSchool` (previous day).

## Bundle IDs

- iOS: `kr.poi.Noa`
- Watch: `kr.poi.Noa.watchkitapp`
- Widget: `kr.poi.Noa.watchkitapp.NoaWidget`
- App Group: `group.kr.poi.Noa`
- Dev Team: `L29YB35382`
