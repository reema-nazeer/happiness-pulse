import AppKit
import SwiftUI

struct PulseCardView: View {
    let onSubmit: (Int, String, @escaping () -> Void) -> Void

    @State private var selectedScore: Int?
    @State private var sliderValue: Double = 5
    @State private var feedback: String = ""
    @State private var loading = false
    @State private var glowRotation = 0.0

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                HomeyLogoView()
                    .frame(width: 120)

                Text("How happy are you at Homey?")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(0.5)
            }
            .padding(.bottom, 4)

            if selectedScore == nil {
                Text("Slide to rate")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
            }

            VStack(spacing: 4) {
                Text(emojiForScore(currentScore))
                    .font(.system(size: 40))
                    .rotationEffect(.degrees(selectedScore == nil ? 0 : 4))
                    .transition(.scale.combined(with: .opacity))
                    .id(currentScore ?? 0)
                Text(labelForScore(currentScore))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorForLabel(currentScore))
                    .animation(.easeInOut(duration: 0.2), value: currentScore ?? 0)
            }

            RatingSliderView(
                value: $sliderValue,
                selectedScore: Binding(
                    get: { selectedScore },
                    set: { selectedScore = $0 }
                )
            )
            .frame(height: 70)

            FeedbackEditor(text: $feedback)
                .frame(height: 86)

            Button(action: submit) {
                if loading {
                    BouncingDotsView()
                } else {
                    Text("Submit")
                }
            }
            .buttonStyle(PrimaryShimmerButtonStyle(enabled: selectedScore != nil))
            .disabled(selectedScore == nil || loading)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel("Submit happiness pulse")
            .animation(.easeInOut(duration: 0.25), value: selectedScore != nil)

            (
                Text("100% Anonymous")
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 219 / 255, green: 255 / 255, blue: 0))
                + Text(" - your name is never recorded")
                    .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
            )
            .font(.system(size: 11))
        }
        .padding(24)
        .frame(width: 500)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 4 / 255, green: 4 / 255, blue: 6 / 255).opacity(0.95))
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 124 / 255, green: 87 / 255, blue: 252 / 255).opacity(0.2),
                        .clear
                    ]),
                    center: .topTrailing,
                    startRadius: 5,
                    endRadius: 220
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 124 / 255, green: 87 / 255, blue: 252 / 255),
                            Color(red: 219 / 255, green: 255 / 255, blue: 0),
                            Color(red: 124 / 255, green: 87 / 255, blue: 252 / 255)
                        ]),
                        center: .center,
                        angle: .degrees(glowRotation)
                    ),
                    lineWidth: 2
                )
        )
        .onAppear {
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                glowRotation = 360
            }
        }
    }

    private func submit() {
        guard let selectedScore, !loading else { return }
        loading = true
        onSubmit(selectedScore, feedback) {
            loading = false
        }
    }

    private var currentScore: Int? {
        selectedScore ?? Int(sliderValue.rounded())
    }

    private func glowForButton(_ score: Int) -> Color {
        switch score {
        case 1...3: return Color.red.opacity(0.4)
        case 4...5: return Color.orange.opacity(0.4)
        case 6...7: return Color.yellow.opacity(0.4)
        default: return Color.green.opacity(0.4)
        }
    }

    private func emojiForScore(_ score: Int?) -> String {
        guard let score else { return "😐" }
        let map = [1: "😢", 2: "😞", 3: "😕", 4: "🫤", 5: "😐", 6: "🙂", 7: "😊", 8: "😄", 9: "🤩", 10: "🚀"]
        return map[score] ?? "🙂"
    }

    private func labelForScore(_ score: Int?) -> String {
        guard let score else { return "Pick a score" }
        let map = [1: "Struggling", 2: "Tough", 3: "Meh", 4: "Okay-ish", 5: "Neutral", 6: "Good", 7: "Happy", 8: "Great", 9: "Amazing", 10: "On top of the world!"]
        return map[score] ?? "Good"
    }

    private func colorForLabel(_ score: Int?) -> Color {
        guard let score else { return .gray }
        return glowForButton(score)
    }
}

private struct RatingSliderView: View {
    @Binding var value: Double
    @Binding var selectedScore: Int?
    @State private var lastHapticValue: Int?

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width - 36, 1)
            let thumbX = ((value - 1) / 9) * width

            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1, green: 0.18, blue: 0.18),
                                    Color(red: 1, green: 0.55, blue: 0),
                                    Color(red: 219 / 255, green: 255 / 255, blue: 0),
                                    Color(red: 0, green: 0.87, blue: 0.42)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 8)

                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 36, height: 36)
                            .shadow(color: .black.opacity(0.24), radius: 8, x: 0, y: 4)
                        Text("\(Int(value.rounded()))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 4 / 255, green: 4 / 255, blue: 6 / 255))
                    }
                    .offset(x: thumbX)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: value)
                }
                .frame(height: 36)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            updateValue(with: drag.location.x, width: width)
                        }
                )

                HStack {
                    Text("1")
                    Spacer()
                    Text("10")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
            }
        }
    }

    private func updateValue(with x: CGFloat, width: CGFloat) {
        let clamped = min(max(x - 18, 0), width)
        let raw = 1 + (Double(clamped / width) * 9)
        let snapped = min(max(Int(raw.rounded()), 1), 10)
        value = Double(snapped)
        selectedScore = snapped
        if lastHapticValue != snapped {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            lastHapticValue = snapped
        }
    }
}

private struct FeedbackEditor: View {
    @Binding var text: String
    @State private var isFocused = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 14))
                .padding(8)
                .background(Color(red: 0.04, green: 0.04, blue: 0.04))
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isFocused ? Color(red: 124 / 255, green: 87 / 255, blue: 252 / 255).opacity(0.9) : Color(red: 0.13, green: 0.13, blue: 0.13), lineWidth: 1.2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onTapGesture { isFocused = true }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Anything you'd like to share? (optional)")
                    .font(.system(size: 14).italic())
                    .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                    .padding(.top, 14)
                    .padding(.leading, 14)
            }
        }
        .accessibilityLabel("Optional feedback")
    }
}

private struct BouncingDotsView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(red: 4 / 255, green: 4 / 255, blue: 6 / 255))
                    .frame(width: 6, height: 6)
                    .offset(y: animate ? -4 : 0)
                    .animation(
                        Animation.easeInOut(duration: 0.35)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.12),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct PrimaryShimmerButtonStyle: ButtonStyle {
    let enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(enabled ? Color(red: 4 / 255, green: 4 / 255, blue: 6 / 255) : Color(red: 0.4, green: 0.4, blue: 0.4))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(enabled ? Color(red: 219 / 255, green: 255 / 255, blue: 0) : Color(red: 0.2, green: 0.2, blue: 0.2))
                    if enabled {
                        ShimmerBandView()
                            .mask(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeInOut(duration: 0.2), value: enabled)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

private struct ShimmerBandView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.55), Color.clear]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: proxy.size.width * 0.38)
            .offset(x: phase * proxy.size.width * 1.8)
            .onAppear {
                withAnimation(.linear(duration: 3.8).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
        .clipped()
    }
}
