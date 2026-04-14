import SwiftUI

struct HomeyLogoView: View {
    var body: some View {
        HStack(spacing: 1) {
            Text("h")
            ZStack {
                Circle()
                    .stroke(Color(red: 219 / 255, green: 255 / 255, blue: 0), lineWidth: 2)
                    .frame(width: 22, height: 22)
                Image(systemName: "house.fill")
                    .font(.system(size: 10, weight: .bold))
            }
            Text("mey")
        }
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundColor(Color(red: 219 / 255, green: 255 / 255, blue: 0))
        .accessibilityLabel("Homey")
    }
}
