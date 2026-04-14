import SwiftUI

struct FirstLaunchView: View {
    @State private var enteredName: String = ""
    @State private var waving = false
    let onComplete: (String) -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "house.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 219 / 255, green: 255 / 255, blue: 0))
                    .accessibilityHidden(true)
                Text("👋")
                    .font(.system(size: 24))
                    .rotationEffect(.degrees(waving ? 16 : -8))
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: waving)
            }
            .onAppear { waving = true }

            Text("Welcome to Happiness Pulse!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Before we begin, please enter your name below.")
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))

            explanation
                .padding(12)
                .background(Color(red: 0.07, green: 0.07, blue: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.13, green: 0.13, blue: 0.13), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            AutoFocusTextField(text: $enteredName, placeholder: "Your full name")
                .frame(height: 44)

            Button("Get Started") {
                let sanitized = enteredName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard sanitized.count >= 2 else { return }
                onComplete(sanitized)
            }
            .buttonStyle(PrimaryShimmerButtonStyle(enabled: enteredName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2))
            .disabled(enteredName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
            .accessibilityLabel("Get Started")
        }
        .padding(26)
        .frame(width: 460)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 4 / 255, green: 4 / 255, blue: 6 / 255).opacity(0.86))
        )
    }

    private var explanation: some View {
        Text("This is a one-time setup to help us confirm your installation was successful. Your name is ")
            .font(.system(size: 13))
            .foregroundColor(Color(red: 0.67, green: 0.67, blue: 0.67))
            + Text("ONLY").font(.system(size: 13, weight: .bold)).foregroundColor(Color(red: 219 / 255, green: 255 / 255, blue: 0))
            + Text(" used to track who has downloaded the app - it is ")
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.67, green: 0.67, blue: 0.67))
            + Text("NEVER").font(.system(size: 13, weight: .bold)).foregroundColor(Color(red: 219 / 255, green: 255 / 255, blue: 0))
            + Text(" linked to your daily happiness responses, which are always 100% anonymous.")
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.67, green: 0.67, blue: 0.67))
    }
}

private struct AutoFocusTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.font = .systemFont(ofSize: 14, weight: .medium)
        textField.wantsLayer = true
        textField.layer?.cornerRadius = 12
        textField.layer?.borderWidth = 1
        textField.layer?.borderColor = NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.13, alpha: 1).cgColor
        textField.backgroundColor = NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.04, alpha: 1)
        textField.textColor = .white
        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
        }
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            text = tf.stringValue
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
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.35), Color.clear]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .blendMode(.screen)
                        .mask(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
