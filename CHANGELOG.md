# Changelog

## 0.4.0 (build 7)
- Fix: the ask prompt could appear up to 30 seconds after the countdown reached zero. Cause: the
  check loop ran every 15 seconds and the notification asked for time-sensitive delivery without
  the entitlement. The loop now runs every second.
- A "keep on" allowance is saved, so relaunching or updating the app no longer drops it, and the
  check runs as soon as the allowance ends instead of up to a full interval later.

## 0.4.0 (build 6)
- App icon: green Wi-Fi with a red power badge.
- Timer window ("Show Timer…" in the menu): countdown to the next check and what it will do.
- Optional Dock icon with a minutes-left badge (Settings, or `showInDock` via profile). Clicking
  the Dock icon opens the timer window.

## 0.3.0 (build 5)
- Fix: a changed check interval (Settings or a profile) only took effect after the check already
  scheduled under the old interval, so the first check after installing a 2 minute profile could
  come several minutes late. Cause: the next check time was fixed when scheduled and never
  recomputed. It now applies to the pending check too.

## 0.3.0 (build 4)
- Fix: Settings did not open from the menu. Cause: the SwiftUI Settings scene is opened by
  sending an action through the responder chain, which a menu bar app without a main menu does
  not have. Settings is now a regular window opened like Help.

## 0.3.0 (build 3)
- Keep-on durations are configurable (up to three, in minutes; default 5, 15, 30) in Settings
  and via the `snoozeOptions` managed key. Menu and notification buttons follow them.
- Settings and Help windows now come to the front. Cause: a menu bar app has no Dock icon, so
  macOS left newly opened windows behind other apps; they are now ordered front explicitly.

## 0.2.0 (build 2)
- MDM support: `mode`, `intervalMinutes`, `lockoutGuard`, `allowSnooze` can be forced by a
  configuration profile; forced settings are locked in the menu and Settings.
- Help window, light grey icon when the guard is paused, test profiles in `MDM/`.
- Manual turn-off asks for confirmation when Wi-Fi is the only connection.

## 0.1.0 (build 1)
- First version: periodic check, ask or silent turn-off, keep-on timers, lockout guard.
