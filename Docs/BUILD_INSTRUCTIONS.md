# Building Wi-Fi Guard

Requires Xcode 15 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open "Wi-Fi Guard.xcodeproj"
```

`project.yml` is the source of truth for the project; edit it and regenerate rather than
editing the `.xcodeproj` by hand. The version and build number are `MARKETING_VERSION` and
`CURRENT_PROJECT_VERSION` there.

The app is not sandboxed (see `Wi-Fi Guard/WiFiGuard.entitlements`) and runs as a menu bar app
(`LSUIElement`). Set your own development team in Xcode to run a local build.

## Command line build

```bash
xcodebuild -project "Wi-Fi Guard.xcodeproj" -scheme "Wi-Fi Guard" -configuration Debug build
```

## Release

Distribution is a Developer ID signed, notarized and stapled disk image. Use your own signing
identity and notarytool keychain profile:

```bash
export MAC_APP_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export MAC_APP_TEAM_ID='TEAMID'
export MAC_APP_NOTARY_PROFILE='your-notary-profile'
```

then archive, sign, notarize and staple with your usual process, and verify with
`spctl --assess --type execute` and `xcrun stapler validate`.

## Testing profile behaviour

Install one of the test profiles in `MDM/` (see `MDM/README.md`) and confirm that the controls
are locked and that checks follow the profile's mode and interval.
