# MDM configuration

Wi-Fi Guard reads its settings from the preference domain `com.wifiguard.app`. A key delivered
by a configuration profile as a forced preference is locked in the app (greyed out, with a
note in the menu and Settings).

| Key | Type | Values | Default |
| --- | --- | --- | --- |
| `mode` | String | `ask`, `silent`, `paused` | `ask` |
| `intervalMinutes` | Integer | 1 to 60 | 5 |
| `lockoutGuard` | Boolean | never turn Wi-Fi off if it is the only connection | true |
| `allowSnooze` | Boolean | allow "Keep Wi-Fi On For" | true |
| `snoozeOptions` | String | up to three keep-on durations in minutes, for example `5, 15, 30` | `5, 15, 30` |

Deploy as a Custom Settings payload (`com.apple.ManagedClient.preferences`) with the
domain `com.wifiguard.app` and the keys above; the Jamf "Application & Custom Settings"
payload with a JSON or plist body works the same way. The manual Wi-Fi toggle is never
restricted.

## Test profiles

- `WiFiGuard-Test-Silent-2min.mobileconfig`: silent mode every 2 minutes, snooze disabled.
- `WiFiGuard-Test-Ask-2min.mobileconfig`: ask mode every 2 minutes.

Install: double-click the file, then System Settings > General > Device Management (or
Privacy & Security > Profiles) > Install. Remove it from the same place.

## Check what the app sees

```bash
sudo profiles show -type configuration
defaults read com.wifiguard.app
```
