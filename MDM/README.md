# MDM configuration

Wi-Fi Guard reads its settings from the preference domain `com.wifiguard.app`. A key delivered
by a configuration profile as a forced preference is locked in the app (greyed out, with a
note in the menu and Settings).

| Key | Type | Values | Default |
| --- | --- | --- | --- |
| `mode` | String | `ask`, `silent` (turn off automatically), `paused` | `ask` |
| `intervalMinutes` | Integer | 1 to 60 | 5 |
| `lockoutGuard` | Boolean | never turn Wi-Fi off if it is the only connection | true |
| `allowSnooze` | Boolean | allow "Keep Wi-Fi On For" | true |
| `launchAtLogin` | Boolean | open at login; the app registers or removes its login item to match | false |
| `showInDock` | Boolean | show a Dock icon with a countdown badge | false |
| `dockBadge` | Boolean | minutes left on the Dock icon (only with `showInDock`) | true |
| `notifyOnAutoOff` | Boolean | notify when Wi-Fi is turned off automatically | true |
| `notifyIntervalMinutes` | Integer | at most one such notification per this many minutes; 0 for every one | 60 |
| `logRotation` | String | `weekly` or `monthly`: when the activity log is compressed | `monthly` |
| `logKeep` | Integer | number of compressed logs kept (1 to 120) | 12 |
| `snoozeOptions` | String | up to three keep-on durations in minutes, for example `5, 15, 30` | `5, 15, 30` |

Deploy as a Custom Settings payload (`com.apple.ManagedClient.preferences`) with the
domain `com.wifiguard.app` and the keys above; the Jamf "Application & Custom Settings"
payload with a JSON or plist body works the same way. The manual Wi-Fi toggle is never
restricted.

## Test profiles

- `WiFiGuard-Test-Silent-2min.mobileconfig`: silent mode every 2 minutes, snooze disabled.
- `WiFiGuard-Test-Ask-2min.mobileconfig`: ask mode every 2 minutes.
- `WiFiGuard-Test-Auto-Notify-Login-Dock.mobileconfig`: automatic turn-off every 2 minutes with a
  notification, plus open at login, the Dock icon with its badge and weekly log compression.
  Note it forces open at login on; removing the profile does not remove the login item.
- `WiFiGuard-Test-Ask-2min-KeepOn-1-3-5.mobileconfig`: as above, plus `snoozeOptions` `1, 3, 5`, so
  the keep-on choices are fixed at 1, 3 and 5 minutes and that field is locked.

Install: double-click the file, then System Settings > General > Device Management (or
Privacy & Security > Profiles) > Install. Remove it from the same place.

## Check what the app sees

```bash
sudo profiles show -type configuration
defaults read com.wifiguard.app
```
