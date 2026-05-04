import SwiftUI

/// Post-submit success card. The previous version used 170 SpriteKit confetti
/// nodes which caused a visible frame drop on older laptops. This version is
/// CSS-style animation only:
///
///   1. Storm Purple ring scales in (spring, ~350ms)
///   2. Strike Yellow checkmark draws (300ms, starts at 200ms)
///   3. "Thanks for sharing" + message fade in (200ms each, starts at 400/500ms)
///   4. Soft brand-coloured halo pulses behind the ring (subtle, no overdraw)
///
/// Total animation completes well under 1 second.
struct ConfirmationView: View {
    let message: String

    @State private var ringScale: CGFloat = 0
    @State private var ringHaloOpacity: Double = 0
    @State private var drawCheck: CGFloat = 0
    @State private var titleOpacity: Double = 0
    @State private var messageOpacity: Double = 0

    private let purple = Color(red: 124 / 255, green: 87 / 255, blue: 252 / 255)
    private let yellow = Color(red: 219 / 255, green: 255 / 255, blue: 0)
    private let black = Color(red: 4 / 255, green: 4 / 255, blue: 6 / 255)

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                // Soft halo behind the ring
                Circle()
                    .fill(purple.opacity(0.25))
                    .frame(width: 110, height: 110)
                    .blur(radius: 18)
                    .opacity(ringHaloOpacity)

                // The Storm Purple ring
                Circle()
                    .fill(purple)
                    .frame(width: 80, height: 80)
                    .shadow(color: purple.opacity(0.45), radius: 14, x: 0, y: 6)
                    .scaleEffect(ringScale)

                // Strike Yellow checkmark, drawn with stroke
                CheckmarkShape()
                    .trim(from: 0, to: drawCheck)
                    .stroke(yellow, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 38, height: 38)
                    .scaleEffect(ringScale)
            }
            .frame(width: 110, height: 110)

            VStack(spacing: 6) {
                Text("Thanks for sharing")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(titleOpacity)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.7))
                    .multilineTextAlignment(.center)
                    .opacity(messageOpacity)
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 30)
        .frame(width: 460)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(black.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(purple.opacity(0.35), lineWidth: 1)
        )
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            ringScale = 1
        }
        withAnimation(.easeOut(duration: 0.6)) {
            ringHaloOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
            drawCheck = 1
        }
        withAnimation(.easeOut(duration: 0.2).delay(0.4)) {
            titleOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.2).delay(0.5)) {
            messageOpacity = 1
        }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.midY + rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.04, y: rect.maxY - rect.height * 0.16))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.minY + rect.height * 0.20))
        return path
    }
}
