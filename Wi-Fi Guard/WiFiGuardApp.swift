import SwiftUI

extension Notification.Name {
    static let showTimerWindow = Notification.Name("WiFiGuard.showTimerWindow")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let showInDock = UserDefaults.standard.bool(forKey: DefaultsKey.showInDock)
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    /// Clicking the Dock icon (or reopening the app) shows the timer window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .showTimerWindow, object: nil)
        return false
    }
}

@main
struct WiFiGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.openWindow) private var openWindow
    @State private var model = GuardModel()
    @AppStorage(DefaultsKey.mode) private var modeRaw = GuardMode.ask.rawValue

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model, modeRaw: $modeRaw)
        } label: {
            Image(nsImage: MenuBarIcon.image(
                wifiOn: model.wifiOn, allowed: model.snoozedUntil != nil,
                paused: GuardMode(rawValue: modeRaw) == .paused))
                .onReceive(NotificationCenter.default.publisher(for: .showTimerWindow)) { _ in
                    openWindow(id: "timer")
                    WindowFront.bring(titleContaining: "Timer")
                }
        }

        Window("Wi-Fi Guard Timer", id: "timer") {
            TimerView(model: model)
        }
        .windowResizability(.contentSize)

        Window("Wi-Fi Guard Settings", id: "settings") {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)

        Window("Wi-Fi Guard Help", id: "help") {
            HelpView(model: model)
        }
        .windowResizability(.contentSize)
    }
}

struct MenuContent: View {
    let model: GuardModel
    @Binding var modeRaw: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(statusLine)
        if model.isManagedAny { Text("Settings managed by your organization") }
        Divider()
        Button(model.wifiOn ? "Turn Wi-Fi Off" : "Turn Wi-Fi On") { model.toggleWiFi() }
        Menu("Keep Wi-Fi On For") {
            ForEach(model.snoozeChoices, id: \.self) { minutes in
                Button(GuardModel.label(minutes: minutes)) { model.snooze(minutes: minutes) }
            }
            if model.snoozedUntil != nil {
                Divider()
                Button("End Now") { model.clearSnooze() }
            }
        }
        .disabled(!model.snoozeAllowed)
        Divider()
        Picker("When Wi-Fi is on", selection: $modeRaw) {
            ForEach(GuardMode.allCases) { Text($0.title).tag($0.rawValue) }
        }
        .disabled(model.isManaged(DefaultsKey.mode))
        Button("Check Now") { model.checkNow() }
        Button("Show Timer…") {
            openWindow(id: "timer")
            WindowFront.bring(titleContaining: "Timer")
        }
        Divider()
        Button("Help…") {
            openWindow(id: "help")
            WindowFront.bring(titleContaining: "Help")
        }
        Button("Settings…") {
            openWindow(id: "settings")
            WindowFront.bring(titleContaining: "Settings")
        }
        Button("Quit Wi-Fi Guard") { NSApplication.shared.terminate(nil) }
    }

    private var statusLine: String {
        if let until = model.snoozedUntil {
            return "Wi-Fi allowed until \(until.formatted(date: .omitted, time: .shortened))"
        }
        if !model.wifiOn { return "Wi-Fi is off" }
        if GuardMode(rawValue: modeRaw) == .paused { return "Wi-Fi is on (guard paused)" }
        return "Wi-Fi is on. Next check \(model.nextCheck.formatted(date: .omitted, time: .shortened))"
    }
}

/// Coloured (non-template) menu bar icon: green = Wi-Fi on, orange = on and allowed for a while,
/// red slashed = off, light grey = guard paused.
enum MenuBarIcon {
    static func image(wifiOn: Bool, allowed: Bool, paused: Bool) -> NSImage {
        let name = wifiOn ? (allowed ? "wifi.circle.fill" : "wifi") : "wifi.slash"
        let color: NSColor = paused ? .systemGray
            : wifiOn ? (allowed ? .systemOrange : .systemGreen) : .systemRed
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            .applying(.init(paletteColors: [color]))
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Wi-Fi Guard")?
            .withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = false
        return image
    }
}

/// Menu bar apps have no Dock presence, so a window they open can land behind other apps.
enum WindowFront {
    static func bring(titleContaining text: String) {
        NSApp.activate(ignoringOtherApps: true)
        for delay in [0.05, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first { $0.title.contains(text) }?.makeKeyAndOrderFront(nil)
                NSApp.windows.first { $0.title.contains(text) }?.orderFrontRegardless()
            }
        }
    }
}
