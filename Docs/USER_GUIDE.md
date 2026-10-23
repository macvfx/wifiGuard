# Wi-Fi Guard user guide

## The menu bar icon

| Icon | Meaning |
| --- | --- |
| Green Wi-Fi | Wi-Fi is on and the guard is watching |
| Orange Wi-Fi in a circle | Wi-Fi is on and allowed for a while |
| Red slashed Wi-Fi | Wi-Fi is off |
| Light grey | The guard is paused |

## Modes

- **Ask me:** at each check, if Wi-Fi is on, a notification asks whether you still need it.
  Choose a keep-on time or "Turn off now". Ignoring it leaves Wi-Fi on until the next check.
- **Turn off automatically:** at each check, if Wi-Fi is on, it is turned off without asking.
  A notification says so, with a button to turn Wi-Fi back on. By default at most one
  notification is sent per hour; anything in between is only written to the activity log.
  Both are in Settings.
- **Paused:** nothing happens.

Change the mode from the menu or from Settings.

## Keeping Wi-Fi on

Use "Keep Wi-Fi On For" in the menu, or a button on the notification. Nothing is checked until
the time ends, then a check runs straight away. The durations are set in Settings as up to
three minute values, for example `5, 15, 30`.

## The safety net

If no other connection is active (Ethernet, a USB or Thunderbolt adapter, a cellular tether),
Wi-Fi is left on and the log says so. Turning Wi-Fi off from the menu in that situation asks you
to confirm. The Settings toggle turns the safety net off.

## Timer window

"Show Timer…" opens a countdown to the next check, or to the end of a keep-on allowance, with a
line describing what will happen. Turn Wi-Fi On or Off and Check Now are available there too.

## Dock icon

Optional. In Settings, turn on "Show in Dock with a countdown badge". The badge shows the
minutes left until the next check. Clicking the Dock icon opens the timer window.

## Settings

Check interval (1 to 60 minutes), mode, keep-on choices, safety net, Dock icon, open at login,
and an activity log of what the app decided.

## Managed settings

If your organization deploys a configuration profile, the settings it controls are greyed out
and a note says so. Turning Wi-Fi on or off by hand is never restricted. See
[MDM/README.md](../MDM/README.md).

## Activity log

Every decision is written to a log in `~/Library/Application Support/Wi-Fi Guard/Logs/`.
Once a week or month (your choice in Settings) the log is compressed to a `.log.gz` file and
a new one starts. The newest 12 compressed logs are kept by default. "Show Log Folder" opens it.

## Troubleshooting

Show what the app decided:

```bash
/usr/bin/log show --last 15m --predicate 'subsystem == "com.wifiguard.app"' --info
```

Show the settings the app reads, including profile-forced ones:

```bash
defaults read com.wifiguard.app
```

If no notification appears, check System Settings, Notifications, Wi-Fi Guard, and Focus.
