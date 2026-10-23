import SwiftUI

struct SiteFooter: View {
    var body: some View {
        HStack {
            Spacer()
            Link("code.matx.ca", destination: URL(string: "https://code.matx.ca")!)
        }
        .font(.caption)
    }
}
