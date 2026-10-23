# Wi-Fi Guard

A small macOS menu bar app that keeps Wi-Fi from interfering with your other network
connections, without ever blocking it. Every few minutes it checks whether Wi-Fi is on and
either asks whether you still need it or turns it off. Turn it back on whenever you need it;
the guard will come around again later.

Built for Macs that are normally wired (Ethernet, Thunderbolt or USB adapters) where Wi-Fi
being on causes traffic to take the wrong path, but where Wi-Fi is still needed now and then.

## Features

- **Ask or automatic:** a notification asks "Wi-Fi is on, still needed?" with Keep-on buttons, or
  Wi-Fi is turned off automatically with a notification (rate limited, with a button to turn it
  back on). Every event goes to a persistent activity log that is compressed weekly or monthly. A paused mode does nothing.
- **Keep-on timers:** leave Wi-Fi alone for up to three durations you choose (default 5, 15 and
  30 minutes). The allowance survives relaunching or updating the app.
- **Safety net:** if Wi-Fi is your only active connection it is left on, and turning it off by
  hand asks you to confirm. A VPN running over Wi-Fi does not count as another connection.
- **Timer window:** a live countdown to the next check and what it will do.
- **Status at a glance:** a coloured menu bar icon (green on, orange allowed, red off, grey
  paused) and an optional Dock icon with a minutes-left badge.
- **MDM support:** mode, interval, safety net, keep-on options, notifications, open at login, the Dock icon and the log settings can be forced by a
  configuration profile and are then locked in the app. See [MDM/README.md](MDM/README.md).

## Requirements

macOS 14 or later. Not sandboxed (it switches the Wi-Fi radio through CoreWLAN), so it is
distributed outside the Mac App Store, signed with a Developer ID and notarized.

## Documentation

- [User guide](Docs/USER_GUIDE.md)
- [MDM configuration and test profiles](MDM/README.md)
- [Build instructions](Docs/BUILD_INSTRUCTIONS.md)
- [Changelog](CHANGELOG.md)

## Privacy

Wi-Fi Guard makes no network requests, collects nothing and stores only its own preferences
(and the end time of a keep-on allowance) in the app's preference domain `com.wifiguard.app`.

## License

MIT. See [LICENSE](LICENSE).
