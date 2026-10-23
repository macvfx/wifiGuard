import SwiftUI

struct SettingsView: View {
    let model: GuardModel
    @AppStorage(DefaultsKey.mode) private var modeRaw = GuardMode.ask.rawValue
    @AppStorage(DefaultsKey.intervalMinutes) private var interval = 5
    @AppStorage(DefaultsKey.lockoutGuard) private var lockoutGuard = true
    @AppStorage(DefaultsKey.showInDock) private var showInDock = false
    @AppStorage(DefaultsKey.snoozeOptions) private var snoozeOptions = "5, 15, 30"

    var body: some View {
        Form {
            Section {
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
                Toggle("Show in Dock with a countdown badge", isOn: $showInDock)
                    .disabled(model.isManaged(DefaultsKey.showInDock))
                    .onChange(of: showInDock) { model.applyDockPreference() }
                Toggle("Open at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }))
            } footer: {
                if model.isManagedAny {
                    Label("Locked settings are managed by your organization.", systemImage: "lock.fill")
                }
            }
            Section("Activity") {
                if model.log.isEmpty {
                    Text("Nothing yet").foregroundStyle(.secondary)
                } else {
                    List(model.log) { entry in
                        HStack {
                            Text(entry.date.formatted(date: .omitted, time: .standard))
                                .monospacedDigit().foregroundStyle(.secondary)
                            Text(entry.text)
                        }
                    }
                    .frame(minHeight: 140)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.bottom)
    }
}
