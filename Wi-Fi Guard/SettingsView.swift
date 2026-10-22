import SwiftUI

struct SettingsView: View {
    let model: GuardModel
    @AppStorage(DefaultsKey.mode) private var modeRaw = GuardMode.ask.rawValue
    @AppStorage(DefaultsKey.intervalMinutes) private var interval = 5
    @AppStorage(DefaultsKey.lockoutGuard) private var lockoutGuard = true

    var body: some View {
        Form {
            Section {
                Picker("When Wi-Fi is on", selection: $modeRaw) {
                    ForEach(GuardMode.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Stepper("Check every \(interval) min", value: $interval, in: 1...60)
                Toggle("Never turn Wi-Fi off if it is the only connection", isOn: $lockoutGuard)
                Toggle("Open at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }))
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
