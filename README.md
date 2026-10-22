# Wi-Fi Guard

Menu bar app for macOS. Checks every few minutes whether Wi-Fi is on and either asks
whether it is still needed or turns it off silently. Wi-Fi is never blocked: turn it back
on from the menu bar or System Settings whenever you need it.

- Modes: Ask me, Turn off silently, Paused
- "Keep Wi-Fi On For" 30 min, 1 hour, 4 hours
- Lockout guard: Wi-Fi is left on when it is the only active connection
- Developer ID distribution only (not sandboxed). Build with the shared mac-release-kit.

Generate the project with `xcodegen generate` after editing `project.yml`.

## Managed settings (MDM)

Mode, interval, lockout guard and snooze can be forced by a configuration profile and are then
locked in the app. See `MDM/README.md` for the keys and test profiles.
