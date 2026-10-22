import SwiftUI

@main
struct WiFiGuardApp: App {
    @State private var model = GuardModel()
    @AppStorage(DefaultsKey.mode) private var modeRaw = GuardMode.ask.rawValue

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model, modeRaw: $modeRaw)
        } label: {
            Image(nsImage: MenuBarIcon.image(wifiOn: model.wifiOn, allowed: model.snoozedUntil != nil))
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

struct MenuContent: View {
    let model: GuardModel
    @Binding var modeRaw: String

    var body: some View {
        Text(statusLine)
        Divider()
        Button(model.wifiOn ? "Turn Wi-Fi Off" : "Turn Wi-Fi On") { model.toggleWiFi() }
        Menu("Keep Wi-Fi On For") {
            Button("30 minutes") { model.snooze(minutes: 30) }
            Button("1 hour") { model.snooze(minutes: 60) }
            Button("4 hours") { model.snooze(minutes: 240) }
            if model.snoozedUntil != nil {
                Divider()
                Button("End Now") { model.clearSnooze() }
            }
        }
        Divider()
        Picker("When Wi-Fi is on", selection: $modeRaw) {
            ForEach(GuardMode.allCases) { Text($0.title).tag($0.rawValue) }
        }
        Button("Check Now") { model.checkNow() }
        Divider()
        SettingsLink { Text("Settings…") }
            .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
        Button("Quit Wi-Fi Guard") { NSApplication.shared.terminate(nil) }
    }

    private var statusLine: String {
        if let until = model.snoozedUntil {
            return "Wi-Fi allowed until \(until.formatted(date: .omitted, time: .shortened))"
        }
        if !model.wifiOn { return "Wi-Fi is off" }
        return GuardMode(rawValue: modeRaw) == .paused ? "Wi-Fi is on (guard paused)" : "Wi-Fi is on"
    }
}

/// Coloured (non-template) menu bar icon: green = Wi-Fi on, orange = on and allowed for a while,
/// red slashed = off.
enum MenuBarIcon {
    static func image(wifiOn: Bool, allowed: Bool) -> NSImage {
        let name = wifiOn ? (allowed ? "wifi.circle.fill" : "wifi") : "wifi.slash"
        let color: NSColor = wifiOn ? (allowed ? .systemOrange : .systemGreen) : .systemRed
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            .applying(.init(paletteColors: [color]))
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Wi-Fi Guard")?
            .withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = false
        return image
    }
}
