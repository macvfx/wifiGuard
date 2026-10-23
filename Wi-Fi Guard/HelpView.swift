import SwiftUI

struct HelpView: View {
    let model: GuardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Wi-Fi Guard").font(.title2.bold())
            Text("Keeps Wi-Fi from interfering with your other network connections. "
                 + "Wi-Fi is never blocked: turn it back on whenever you need it.")

            item("wifi", "The icon",
                 "Green: Wi-Fi is on. Orange: on and allowed for a while. "
                 + "Red with a slash: off. Light grey: the guard is paused.")
            item("clock", "Checks",
                 "Every few minutes it checks whether Wi-Fi is on. Depending on the mode it asks "
                 + "if you still need it, or turns it off quietly.")
            item("timer", "Timer",
                 "\"Show Timer…\" in the menu shows when the next check happens and what it will do. "
                 + "In Settings you can also show a Dock icon with the minutes left.")
            item("hand.raised", "Keep Wi-Fi on",
                 "Use \"Keep Wi-Fi On For\" in the menu, or a button on the notification, "
                 + "to leave it alone for 30 minutes, 1 hour or 4 hours.")
            item("shield", "Safety net",
                 "If Wi-Fi is your only connection, it is left on, and turning it off by hand "
                 + "asks you to confirm. A VPN over Wi-Fi does not count as another connection.")
            if model.isManagedAny {
                item("lock", "Managed settings",
                     "Some settings are set by your organization and are locked.")
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func item(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).frame(width: 22).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).bold()
                Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
