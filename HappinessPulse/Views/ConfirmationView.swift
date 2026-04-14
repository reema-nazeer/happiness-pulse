import SwiftUI
import SpriteKit

struct ConfirmationView: View {
    let message: String
    @State private var drawCheck = false
    @State private var showConfetti = true

    var body: some View {
        ZStack {
            if showConfetti {
                ConfettiSpriteView()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            VStack(spacing: 14) {
                CheckmarkShape()
                    .trim(from: 0, to: drawCheck ? 1 : 0)
                    .stroke(Color(red: 219 / 255, green: 255 / 255, blue: 0), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .frame(width: 66, height: 66)
                    .animation(.easeOut(duration: 0.5), value: drawCheck)

                Text("Thank you!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(red: 219 / 255, green: 255 / 255, blue: 0))

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.62, green: 0.62, blue: 0.62))
                    .multilineTextAlignment(.center)
            }
            .padding(30)
            .frame(width: 460)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 4 / 255, green: 4 / 255, blue: 6 / 255).opacity(0.85))
            )
        }
        .onAppear {
            drawCheck = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showConfetti = false
                }
            }
        }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY + rect.height * 0.1))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.06, y: rect.maxY - rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY + rect.height * 0.18))
        return path
    }
}

private struct ConfettiSpriteView: NSViewRepresentable {
    func makeNSView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.allowsTransparency = true
        let scene = ConfettiScene(size: NSScreen.main?.frame.size ?? CGSize(width: 1280, height: 720))
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        return view
    }

    func updateNSView(_ nsView: SKView, context: Context) {}
}

private final class ConfettiScene: SKScene {
    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        runBursts()
    }

    private func runBursts() {
        [0.0, 0.3, 0.6].forEach { delay in
            run(.sequence([.wait(forDuration: delay), .run { [weak self] in
                self?.emitBurst()
            }]))
        }
    }

    private func emitBurst() {
        let colors: [NSColor] = [
            NSColor(calibratedRed: 219 / 255, green: 255 / 255, blue: 0, alpha: 1),
            NSColor(calibratedRed: 124 / 255, green: 87 / 255, blue: 252 / 255, alpha: 1),
            NSColor(calibratedRed: 1, green: 0.27, blue: 0.27, alpha: 1),
            NSColor(calibratedRed: 0, green: 0.8, blue: 0.4, alpha: 1),
            NSColor(calibratedRed: 1, green: 0.55, blue: 0, alpha: 1),
            NSColor.white
        ]

        for i in 0..<170 {
            let shapeType = i % 3
            let node: SKShapeNode
            let sizeValue = CGFloat(Int.random(in: 4...12))
            if shapeType == 0 {
                node = SKShapeNode(circleOfRadius: sizeValue / 2)
            } else if shapeType == 1 {
                node = SKShapeNode(rectOf: CGSize(width: sizeValue, height: sizeValue))
            } else {
                node = SKShapeNode(rectOf: CGSize(width: max(2, sizeValue / 3), height: sizeValue + 6))
            }
            node.fillColor = colors.randomElement() ?? .white
            node.strokeColor = .clear
            node.alpha = CGFloat.random(in: 0.7...1)
            node.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + 20)
            addChild(node)

            let drift = CGFloat.random(in: -120...120)
            let destination = CGPoint(x: node.position.x + drift, y: -40)
            let duration = TimeInterval.random(in: 1.8...2.8)
            let move = SKAction.move(to: destination, duration: duration)
            move.timingMode = .easeIn
            let rotate = SKAction.rotate(byAngle: CGFloat.random(in: -3...3), duration: duration)
            let fade = SKAction.fadeOut(withDuration: 0.25)
            node.run(.group([move, rotate]))
            node.run(.sequence([.wait(forDuration: duration - 0.25), fade, .removeFromParent()]))
        }
    }
}
