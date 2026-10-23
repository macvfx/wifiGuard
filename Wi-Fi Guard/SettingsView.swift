import SwiftUI

struct SettingsView: View {
    let model: GuardModel
    @AppStorage(DefaultsKey.mode) private var modeRaw = GuardMode.ask.rawValue
    @AppStorage(DefaultsKey.intervalMinutes) private var interval = 5
    @AppStorage(DefaultsKey.lockoutGuard) private var lockoutGuard = true
    @AppStorage(DefaultsKey.snoozeOptions) private var snoozeOptions = "5, 15, 30"
    @AppStorage(DefaultsKey.notifyOnAutoOff) private var notifyOnAutoOff = true
    @AppStorage(DefaultsKey.notifyIntervalMinutes) private var notifyInterval = 60
    @AppStorage(DefaultsKey.showInDock) private var showInDock = false
    @AppStorage(DefaultsKey.dockBadge) private var dockBadge = true
    @AppStorage(DefaultsKey.logRotation) private var logRotation = "monthly"
    @AppStorage(DefaultsKey.logKeep) private var logKeep = 12

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Checking") {
                    Picker("When Wi-Fi is on", selection: $modeRaw) {
                        ForEach(GuardMode.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .disabled(model.isManaged(DefaultsKey.mode))
                    Stepper("Check every \(interval) min", value: $interval, in: 1...60)
                        .disabled(model.isManaged(DefaultsKey.intervalMinutes))
                    TextField("Keep-on choices (minutes)", text: $snoozeOptions, prompt: Text("5, 15, 30"))
                        .disabled(model.isManaged(DefaultsKey.snoozeOptions)
                                  || model.isManaged(DefaultsKey.allowSnooze))
                    Toggle("Never turn Wi-Fi off if it is the only connection", isOn: $lockoutGuard)
                        .disabled(model.isManaged(DefaultsKey.lockoutGuard))
                }

                Section("Notifications") {
                    Toggle("Notify me when Wi-Fi is turned off automatically", isOn: $notifyOnAutoOff)
                        .disabled(model.isManaged(DefaultsKey.notifyOnAutoOff))
                    Stepper("At most one notification every \(notifyInterval) min", value: $notifyInterval,
                            in: 0...1440, step: 15)
                        .disabled(model.isManaged(DefaultsKey.notifyIntervalMinutes) || !notifyOnAutoOff)
                    Text("Anything in between is only written to the activity log.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Appearance") {
                    Toggle("Show in Dock", isOn: $showInDock)
                        .disabled(model.isManaged(DefaultsKey.showInDock))
                        .onChange(of: showInDock) { model.applyDockPreference() }
                    Toggle("Show minutes left on the Dock icon", isOn: $dockBadge)
                        .disabled(model.isManaged(DefaultsKey.dockBadge) || !showInDock)
                    Toggle("Open at login", isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }))
                        .disabled(model.isManaged(DefaultsKey.launchAtLogin))
                }

                Section {
                    Picker("Compress the log", selection: $logRotation) {
                        Text("Every week").tag("weekly")
                        Text("Every month").tag("monthly")
                    }
                    .disabled(model.isManaged(DefaultsKey.logRotation))
                    Stepper("Keep \(logKeep) compressed logs", value: $logKeep, in: 1...120)
                        .disabled(model.isManaged(DefaultsKey.logKeep))
                    Button("Show Log Folder") { model.showLogFolder() }
                    if model.log.isEmpty {
                        Text("Nothing yet").foregroundStyle(.secondary)
                    } else {
                        List(model.log) { entry in
                            HStack {
                                Text(entry.date.formatted(date: .abbreviated, time: .standard))
                                    .monospacedDigit().foregroundStyle(.secondary)
                                Text(entry.text)
                            }
                        }
                        .frame(minHeight: 140)
                    }
                } header: {
                    Text("Activity log")
                } footer: {
                    if model.isManagedAny {
                        Label("Locked settings are managed by your organization.", systemImage: "lock.fill")
                    }
                }
            }
            .formStyle(.grouped)
            SiteFooter().padding(.horizontal, 20).padding(.bottom, 12)
        }
        .frame(width: 500)
    }
}
