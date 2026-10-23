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
    static let allowSnooze = "allowSnooze"
    static let snoozeOptions = "snoozeOptions"
    static let showInDock = "showInDock"

    /// Keys an MDM configuration profile can force (domain com.wifiguard.app).
    static let managed = [mode, intervalMinutes, lockoutGuard, allowSnooze, snoozeOptions, showInDock]

    static func isForced(_ key: String) -> Bool {
        UserDefaults.standard.objectIsForced(forKey: key)
    }
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
    private(set) var snoozedUntil: Date? {
        didSet { UserDefaults.standard.set(snoozedUntil, forKey: Self.snoozeKey) }
    }
    private(set) var log: [LogEntry] = []
    private(set) var launchAtLogin = false
    /// Settings currently forced by a configuration profile; the UI locks these.
    private(set) var managedKeys: Set<String> = []

    private let wifi = WiFiController()
    private let paths = OtherPathMonitor()
    private(set) var nextCheck = Date()
    private var scheduledFrom = Date()
    private var scheduledInterval: TimeInterval?
    private var timer: Timer?
    private var registeredChoices: [Int] = []

    private static let snoozeKey = "snoozedUntil"
    private static let category = "WIFI_ASK"
    private static let requestID = "wifi-on"

    override init() {
        super.init()
        UserDefaults.standard.register(defaults: [
            DefaultsKey.mode: GuardMode.ask.rawValue,
            DefaultsKey.intervalMinutes: 5,
            DefaultsKey.lockoutGuard: true,
            DefaultsKey.allowSnooze: true,
            DefaultsKey.snoozeOptions: "5, 15, 30",
            DefaultsKey.showInDock: false,
        ])
        refreshManaged()
        // An allowance survives a relaunch or an update.
        if let saved = UserDefaults.standard.object(forKey: Self.snoozeKey) as? Date, saved > Date() {
            snoozedUntil = saved
        }
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
        registerCategory()
        center.requestAuthorization(options: [.alert]) { _, _ in }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    // MARK: Settings

    /// What the next check will do, for the timer window.
    var nextActionText: String {
        if mode == .paused { return "Guard is paused" }
        if let until = snoozedUntil {
            return "Wi-Fi allowed until \(until.formatted(date: .omitted, time: .shortened))"
        }
        if !wifiOn { return "Wi-Fi is off. Nothing to do." }
        if UserDefaults.standard.bool(forKey: DefaultsKey.lockoutGuard), !paths.hasOtherPath {
            return "Wi-Fi is your only connection, so it will be left on"
        }
        return mode == .silent ? "Wi-Fi will be turned off" : "You will be asked about Wi-Fi"
    }

    var showInDock: Bool { UserDefaults.standard.bool(forKey: DefaultsKey.showInDock) }

    func applyDockPreference() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        updateDockBadge()
    }

    private func updateDockBadge() {
        guard showInDock, wifiOn, mode != .paused, snoozedUntil == nil else {
            NSApp.dockTile.badgeLabel = nil
            return
        }
        let minutes = max(0, Int((nextCheck.timeIntervalSinceNow / 60).rounded(.up)))
        NSApp.dockTile.badgeLabel = "\(minutes)m"
    }

    func isManaged(_ key: String) -> Bool { managedKeys.contains(key) }

    var isManagedAny: Bool { !managedKeys.isEmpty }

    var snoozeAllowed: Bool { UserDefaults.standard.bool(forKey: DefaultsKey.allowSnooze) }

    /// Keep-on durations in minutes: up to three positive numbers from the `snoozeOptions` string.
    var snoozeChoices: [Int] {
        let raw = UserDefaults.standard.string(forKey: DefaultsKey.snoozeOptions) ?? ""
        let values = raw.split { !$0.isNumber }.compactMap { Int($0) }.filter { (1...1440).contains($0) }
        return Array((values.isEmpty ? [5, 15, 30] : values).prefix(3))
    }

    static func label(minutes: Int) -> String {
        if minutes % 60 == 0 { return minutes == 60 ? "1 hour" : "\(minutes / 60) hours" }
        return "\(minutes) min"
    }

    private func registerCategory() {
        registeredChoices = snoozeChoices
        var actions = registeredChoices.map {
            UNNotificationAction(identifier: "keep:\($0)", title: "Keep on \(Self.label(minutes: $0))")
        }
        if !snoozeAllowed { actions = [] }
        actions.append(UNNotificationAction(identifier: "off", title: "Turn off now", options: [.destructive]))
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: actions, intentIdentifiers: [])
        ])
    }

    private func refreshManaged() {
        if registeredChoices != snoozeChoices { registerCategory() }
        let forced = Set(DefaultsKey.managed.filter(DefaultsKey.isForced))
        if forced != managedKeys { managedKeys = forced }
    }

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
        guard snoozeAllowed else {
            record("Keep-on request ignored: not allowed by policy")
            return
        }
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
        scheduledFrom = Date()
        scheduledInterval = seconds == nil ? intervalSeconds : nil
        nextCheck = scheduledFrom.addingTimeInterval(seconds ?? intervalSeconds)
    }

    private func tick() {
        refreshManaged()
        wifiOn = wifi.isOn
        if let until = snoozedUntil, until <= Date() {
            snoozedUntil = nil
            nextCheck = Date()  // check as soon as the allowance ends, not a full interval later
            record("Allowance ended")
        }
        // A new interval (setting or profile) applies to the pending check, not only the next one.
        if let scheduled = scheduledInterval, scheduled != intervalSeconds {
            scheduledInterval = intervalSeconds
            nextCheck = scheduledFrom.addingTimeInterval(intervalSeconds)
        }
        updateDockBadge()
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
            case "off": setWiFi(false, reason: "You chose")
            case _ where action.hasPrefix("keep:"):
                if let minutes = Int(action.dropFirst(5)) { snooze(minutes: minutes) }
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
