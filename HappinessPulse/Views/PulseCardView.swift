import AppKit
import SwiftUI

struct PulseCardView: View {
    /// If set, the department is baked in by the install (v3 per-dept
    /// installer) and the card skips the picker step.  Nil on v2.1.0
    /// laptops, where we show the 4-pill picker.
    let installedDepartment: String?

    /// Submit callback — score, feedback, department, optional sub-department, completion.
    let onSubmit: (Int, String, String, String?, @escaping () -> Void) -> Void

    @State private var selectedScore: Int?
    @State private var sliderValue: Double = 5
    @State private var feedback: String = ""
    @State private var department: String?
    @State private var subDepartment: String = ""
    @State private var loading = false
    @State private var glowRotation = 0.0

    private let departments = ["Operations", "Revenue", "Service", "Technology"]

    /// Dept used for submission. Comes from the install config in v3, or
    /// from the picker selection in v2.1.0 fallback mode.
    private var effectiveDepartment: String? {
        installedDepartment ?? department
    }

    init(
        installedDepartment: String? = nil,
        onSubmit: @escaping (Int, String, String, String?, @escaping () -> Void) -> Void
    ) {
        self.installedDepartment = installedDepartment
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                HomeyLogoView()
                    .frame(width: 120)

                if let installedDepartment {
                    // v3: dept baked into the install — show as a header.
                    Text("\(installedDepartment) Pulse")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    Text("How happy are you at Homey today?")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.7))
                } else {
                    Text("How happy are you at Homey?")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 4)

            // v2.1.0 fallback: show the 4-pill picker only when no
            // department was baked in at install time.
            if installedDepartment == nil {
                DepartmentPicker(
                    departments: departments,
                    selected: $department
                )
            }

            if effectiveDepartment != nil {
                SubDepartmentField(text: $subDepartment)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if selectedScore == nil {
                Text("Slide to rate")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.6))
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
            .buttonStyle(PrimaryShimmerButtonStyle(enabled: canSubmit))
            .disabled(!canSubmit || loading)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel("Submit happiness pulse")
            .animation(.easeInOut(duration: 0.25), value: canSubmit)

            (
                Text("100% Anonymous")
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 219 / 255, green: 255 / 255, blue: 0))
                + Text(" - your name is never recorded")
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.6))
            )
            .font(.system(size: 11))
        }
        .padding(24)
        .frame(width: 500)
        .animation(.easeInOut(duration: 0.25), value: department)
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
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                glowRotation = 360
            }
        }
    }

    private var canSubmit: Bool {
        selectedScore != nil && effectiveDepartment != nil
    }

    private func submit() {
        guard let selectedScore, let dept = effectiveDepartment, !loading else { return }
        loading = true
        let trimmedSub = subDepartment.trimmingCharacters(in: .whitespacesAndNewlines)
        onSubmit(selectedScore, feedback, dept, trimmedSub.isEmpty ? nil : trimmedSub) {
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

// MARK: - Department picker

private struct DepartmentPicker: View {
    let departments: [String]
    @Binding var selected: String?

    var body: some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(departments, id: \.self) { dept in
                let isSelected = selected == dept
                Button {
                    selected = dept
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                } label: {
                    Text(dept)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .foregroundColor(isSelected ? .white : Color(red: 124 / 255, green: 87 / 255, blue: 252 / 255))
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected
                                      ? Color(red: 124 / 255, green: 87 / 255, blue: 252 / 255)
                                      : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(red: 124 / 255, green: 87 / 255, blue: 252 / 255), lineWidth: 1.5)
                        )
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(dept) department")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Optional sub-department free-text input

private struct SubDepartmentField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Text("Team")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.6))
                .textCase(.uppercase)
                .frame(width: 44, alignment: .leading)

            DarkTextField(text: $text, placeholder: "Sub-department (optional)")
                .frame(height: 32)
        }
    }
}

/// NSTextField-backed input. Avoids SwiftUI TextField's macOS rendering quirks
/// (notably the white-on-white typing bug we hit with TextEditor) and gives us
/// full control over colours.
private struct DarkTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        field.textColor = .white
        field.font = NSFont.systemFont(ofSize: 13)
        field.focusRingType = .none
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor(calibratedRed: 0.45, green: 0.45, blue: 0.48, alpha: 1.0),
                .font: NSFont.systemFont(ofSize: 13).italic()
            ]
        )
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.cell?.lineBreakMode = .byClipping
        // Inset the text a few pixels for breathing room.
        if let cell = field.cell as? NSTextFieldCell {
            cell.title = text
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

private extension NSFont {
    func italic() -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}

// MARK: - Slider

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
                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.6))
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

// MARK: - Feedback editor (typing-not-visible bug fixed here)

private struct FeedbackEditor: NSViewRepresentable {
    @Binding var text: String

    private let darkBg = NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
    private let borderInactive = NSColor(calibratedRed: 0.18, green: 0.18, blue: 0.22, alpha: 1.0)
    private let borderActive = NSColor(calibratedRed: 124 / 255, green: 87 / 255, blue: 252 / 255, alpha: 0.9)

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = darkBg
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 12
        scroll.layer?.masksToBounds = true
        scroll.layer?.borderWidth = 1.2
        scroll.layer?.borderColor = borderInactive.cgColor

        let textView = AccessiblePlaceholderTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        // The fix: explicit dark background AND white text on an NSTextView we
        // own outright. SwiftUI's TextEditor draws its own white scroll
        // content background ON TOP of any .background(...) modifier, which
        // produced the white-on-white invisible-typing bug. Wrapping
        // NSTextView keeps colours under our control on every macOS version.
        textView.drawsBackground = true
        textView.backgroundColor = darkBg
        textView.textColor = .white
        textView.insertionPointColor = NSColor(calibratedRed: 124 / 255, green: 87 / 255, blue: 252 / 255, alpha: 1.0)
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.delegate = context.coordinator
        textView.placeholderText = "Anything you'd like to share? (optional)"
        textView.placeholderColor = NSColor(calibratedRed: 0.45, green: 0.45, blue: 0.48, alpha: 1.0)
        textView.placeholderFont = NSFont.systemFont(ofSize: 14).italic()
        textView.string = text
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scroll.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )

        context.coordinator.textView = textView
        context.coordinator.scrollView = scroll
        context.coordinator.borderInactive = borderInactive
        context.coordinator.borderActive = borderActive

        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? AccessiblePlaceholderTextView,
           textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let text: Binding<String>
        weak var textView: AccessiblePlaceholderTextView?
        weak var scrollView: NSScrollView?
        // Defaults are overwritten by makeNSView before the view is ever
        // shown; just need any valid NSColor here. The previous default
        // tried `NSColor.gray.cgColor as Any as! NSColor` which crashes at
        // runtime because CGColor isn't an NSColor.
        var borderInactive: NSColor = .gray
        var borderActive: NSColor = .gray

        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text.wrappedValue = tv.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            updateBorder()
        }

        func textDidBeginEditing(_ notification: Notification) {
            updateBorder()
        }

        func textDidEndEditing(_ notification: Notification) {
            updateBorder()
        }

        private func updateBorder() {
            guard let scrollView else { return }
            let isFocused = textView?.window?.firstResponder == textView
            scrollView.layer?.borderColor = isFocused ? borderActive.cgColor : borderInactive.cgColor
        }
    }
}

/// NSTextView subclass that draws a placeholder string when empty.
private final class AccessiblePlaceholderTextView: NSTextView {
    var placeholderText: String = ""
    var placeholderColor: NSColor = .gray
    var placeholderFont: NSFont = NSFont.systemFont(ofSize: 14)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholderText.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: placeholderColor,
            .font: placeholderFont
        ]
        let inset = textContainerInset
        let origin = NSPoint(x: inset.width + 4, y: inset.height)
        placeholderText.draw(at: origin, withAttributes: attrs)
    }
}

// MARK: - Submit button bits (unchanged)

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
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
        .clipped()
    }
}
