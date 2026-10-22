import AppKit
import Observation
import os
import ServiceManagement
import UserNotifications

enum GuardMode: String, CaseIterable, Identifiable {
    case ask, silent, paused
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ask: "Ask me"
        case .silent: "Turn off silently"
        case .paused: "Paused"
        }
    }
}

enum DefaultsKey {
    static let mode = "mode"
    static let intervalMinutes = "intervalMinutes"
    static let lockoutGuard = "lockoutGuard"
}

struct LogEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
}

@MainActor
@Observable
final class GuardModel: NSObject, UNUserNotificationCenterDelegate {
    private(set) var wifiOn = false
    private(set) var snoozedUntil: Date?
    private(set) var log: [LogEntry] = []
    private(set) var launchAtLogin = false

    private let wifi = WiFiController()
    private let paths = OtherPathMonitor()
    private var nextCheck = Date()
    private var timer: Timer?

    private static let category = "WIFI_ASK"
    private static let requestID = "wifi-on"

    override init() {
        super.init()
        UserDefaults.standard.register(defaults: [
            DefaultsKey.mode: GuardMode.ask.rawValue,
            DefaultsKey.intervalMinutes: 5,
            DefaultsKey.lockoutGuard: true,
        ])
        wifiOn = wifi.isOn
        launchAtLogin = SMAppService.mainApp.status == .enabled
        scheduleNextCheck()

        wifi.onPowerChange = { [weak self] in
            Task { @MainActor in self?.powerChanged() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleNextCheck(after: 20) }
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let actions = [
            UNNotificationAction(identifier: "keep30", title: "Keep on 30 min"),
            UNNotificationAction(identifier: "keep60", title: "Keep on 1 hour"),
            UNNotificationAction(identifier: "off", title: "Turn off now", options: [.destructive]),
        ]
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: actions,
                                   intentIdentifiers: [])
        ])
        center.requestAuthorization(options: [.alert]) { _, _ in }

        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    // MARK: Settings

    var mode: GuardMode {
        GuardMode(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.mode) ?? "") ?? .ask
    }

    private var intervalSeconds: TimeInterval {
        TimeInterval(max(1, UserDefaults.standard.integer(forKey: DefaultsKey.intervalMinutes))) * 60
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            record("Launch at login failed: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Actions

    func toggleWiFi() {
        let turnOn = !wifi.isOn
        if !turnOn, UserDefaults.standard.bool(forKey: DefaultsKey.lockoutGuard),
           !paths.hasOtherPath, !confirmTurnOffOnlyConnection() {
            record("Manual turn-off cancelled: Wi-Fi is the only connection")
            return
        }
        setWiFi(turnOn, reason: "Manual")
    }

    private func confirmTurnOffOnlyConnection() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Turn off your only connection?"
        alert.informativeText = "Wi-Fi appears to be the only active network connection, "
            + "including any VPN that runs over it. Turning it off will disconnect this Mac."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Turn Wi-Fi Off")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertSecondButtonReturn
    }

    func snooze(minutes: Int) {
        snoozedUntil = Date().addingTimeInterval(TimeInterval(minutes) * 60)
        record("Wi-Fi allowed for \(minutes) min")
        clearPrompt()
    }

    func clearSnooze() {
        snoozedUntil = nil
    }

    func checkNow() {
        evaluate()
    }

    // MARK: Scheduling

    private func scheduleNextCheck(after seconds: TimeInterval? = nil) {
        nextCheck = Date().addingTimeInterval(seconds ?? intervalSeconds)
    }

    private func tick() {
        wifiOn = wifi.isOn
        if let until = snoozedUntil, until <= Date() {
            snoozedUntil = nil
            record("Allowance ended")
        }
        guard Date() >= nextCheck else { return }
        scheduleNextCheck()
        evaluate()
    }

    private func powerChanged() {
        let on = wifi.isOn
        guard on != wifiOn else { return }
        wifiOn = on
        if on {
            // However it was turned on, leave it alone for a full interval.
            scheduleNextCheck()
        } else {
            clearPrompt()
        }
    }

    // MARK: Decision

    private func evaluate() {
        wifiOn = wifi.isOn
        guard wifiOn, mode != .paused, snoozedUntil == nil else { return }

        if UserDefaults.standard.bool(forKey: DefaultsKey.lockoutGuard), !paths.hasOtherPath {
            record("Wi-Fi left on: no other connection is active")
            return
        }

        switch mode {
        case .silent: setWiFi(false, reason: "Auto-off")
        case .ask: askUser()
        case .paused: break
        }
    }

    private func setWiFi(_ on: Bool, reason: String) {
        do {
            try wifi.setPower(on)
            wifiOn = on
            record("\(reason): Wi-Fi turned \(on ? "on" : "off")")
            if on { scheduleNextCheck() } else { clearPrompt() }
        } catch {
            record("Could not turn Wi-Fi \(on ? "on" : "off"): \(error.localizedDescription)")
        }
    }

    private func askUser() {
        let content = UNMutableNotificationContent()
        content.title = "Wi-Fi is on"
        content.body = "Do you still need it? It can interfere with other network paths."
        content.categoryIdentifier = Self.category
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: Self.requestID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        record("Asked whether Wi-Fi is still needed")
    }

    private func clearPrompt() {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [Self.requestID])
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestID])
    }

    private func record(_ text: String) {
        Logger(subsystem: "com.wifiguard.app", category: "guard").notice("\(text, privacy: .public)")
        log.insert(LogEntry(text: text), at: 0)
        if log.count > 100 { log.removeLast(log.count - 100) }
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        await MainActor.run {
            switch action {
            case "keep30": snooze(minutes: 30)
            case "keep60": snooze(minutes: 60)
            case "off": setWiFi(false, reason: "You chose")
            default: break
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner]
    }
}
