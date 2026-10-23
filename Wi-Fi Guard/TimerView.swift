import SwiftUI

struct TimerView: View {
    let model: GuardModel

    var body: some View {
        VStack(spacing: 14) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 4) {
                    Text(countdown(at: context.date))
                        .font(.system(size: 54, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(model.wifiOn ? Color.green : Color.red)
                    Text(subtitle).foregroundStyle(.secondary)
                }
            }
            Text(model.nextActionText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(model.wifiOn ? "Turn Wi-Fi Off" : "Turn Wi-Fi On") { model.toggleWiFi() }
                Button("Check Now") { model.checkNow() }
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    private var subtitle: String {
        if !model.wifiOn || model.snoozedUntil != nil { return model.wifiOn ? "until the allowance ends" : "Wi-Fi off" }
        return "until the next check"
    }

    private func countdown(at date: Date) -> String {
        guard model.wifiOn, GuardMode(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.mode) ?? "") != .paused else {
            return "--:--"
        }
        let target = model.snoozedUntil ?? model.nextCheck
        let remaining = max(0, Int(target.timeIntervalSince(date).rounded(.up)))
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}
