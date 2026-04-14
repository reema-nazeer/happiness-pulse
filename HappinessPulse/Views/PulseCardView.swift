import SwiftUI

struct PulseCardView: View {
    let employeeName: String
    let onSubmit: (Int, String, @escaping () -> Void) -> Void

    @State private var selectedScore: Int?
    @State private var hoveredScore: Int?
    @State private var feedback: String = ""
    @State private var loading = false
    @State private var glowRotation = 0.0

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                HomeyLogoView()
                    .frame(width: 120)

                Text("How happy are you?")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(0.5)
                if !employeeName.isEmpty {
                    Text("Hi \(employeeName)")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 219 / 255, green: 255 / 255, blue: 0))
                }
            }
            .padding(.bottom, 4)

            HStack(spacing: 8) {
                ForEach(1...10, id: \.self) { value in
                    Button(action: {
                        selectedScore = value
                    }) {
                        Text("\(value)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.98))
                            .frame(width: 46, height: 46)
                            .background(buttonBackground(for: value))
                            .overlay(Circle().stroke(Color(red: 0.2, green: 0.2, blue: 0.2), lineWidth: 1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(scaleForButton(value))
                    .shadow(color: Color(red: 124 / 255, green: 87 / 255, blue: 252 / 255).opacity(0.22), radius: selectedScore == value ? 10 : 4)
                    .shadow(color: glowForButton(value), radius: selectedScore == value || hoveredScore == value ? 15 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedScore)
                    .onHover { hovering in
                        hoveredScore = hovering ? value : (hoveredScore == value ? nil : hoveredScore)
                    }
                    .focusable(true)
                    .accessibilityLabel("Happiness score \(value)")
                }
            }

            VStack(spacing: 4) {
                Text(emojiForScore(selectedScore ?? hoveredScore))
                    .font(.system(size: 36))
                    .rotationEffect(.degrees((selectedScore ?? hoveredScore) == nil ? 0 : 4))
                    .transition(.scale.combined(with: .opacity))
                    .id(selectedScore ?? hoveredScore ?? 0)
                Text(labelForScore(selectedScore ?? hoveredScore))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorForLabel(selectedScore ?? hoveredScore))
                    .animation(.easeInOut(duration: 0.2), value: selectedScore ?? hoveredScore)
            }

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
        .frame(width: 460)
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

    @ViewBuilder
    private func buttonBackground(for score: Int) -> some View {
        let active = selectedScore == score || hoveredScore == score
        if active {
            Circle().fill(gradientForScore(score))
        } else {
            Circle().fill(Color(red: 124 / 255, green: 87 / 255, blue: 252 / 255).opacity(0.15))
        }
    }

    private func gradientForScore(_ score: Int) -> RadialGradient {
        switch score {
        case 1...3:
            return RadialGradient(gradient: Gradient(colors: [Color(red: 1, green: 0.35, blue: 0.35), Color(red: 1, green: 0.18, blue: 0.18)]), center: .center, startRadius: 3, endRadius: 30)
        case 4...5:
            return RadialGradient(gradient: Gradient(colors: [Color(red: 1, green: 0.62, blue: 0.25), Color(red: 1, green: 0.48, blue: 0)]), center: .center, startRadius: 3, endRadius: 30)
        case 6...7:
            return RadialGradient(gradient: Gradient(colors: [Color(red: 0.86, green: 1, blue: 0.2), Color(red: 0.78, green: 0.9, blue: 0)]), center: .center, startRadius: 3, endRadius: 30)
        default:
            return RadialGradient(gradient: Gradient(colors: [Color(red: 0, green: 0.87, blue: 0.42), Color(red: 0, green: 0.7, blue: 0.34)]), center: .center, startRadius: 3, endRadius: 30)
        }
    }

    private func scaleForButton(_ score: Int) -> CGFloat {
        if selectedScore == score { return 1.18 }
        if hoveredScore == score { return 1.12 }
        return 1.0
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
        guard let score else { return "🙂" }
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
