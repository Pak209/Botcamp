import SwiftUI

extension Color {
    static let brandNavy = Color("BrandNavy")
    static let brandTeal = Color("BrandTeal")
    static let brandLime = Color("BrandLime")
    static let brandOrange = Color("BrandOrange")
    static let brandYellow = Color("BrandYellow")
    static let brandCream = Color("BrandCream")
    static let brandOlive = Color("BrandOlive")
    static let brandPink = Color("BrandPink")
}

enum MascotPose: String { case idle, cheer, thinking, sleeping }

/// Sarge Byte. Idle pose bobs and blinks (port of anim-idle-blink.svg).
struct SargeByte: View {
    var pose: MascotPose = .idle
    var size: CGFloat = 120
    @State private var bob = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Image("mascot-\(pose.rawValue)")
            .resizable().scaledToFit()
            .frame(width: size, height: size)
            .offset(y: bob ? -4 : 4)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: bob)
            .onAppear { bob = pose != .sleeping && !reduceMotion }
            .accessibilityLabel("Sarge Byte, the Botcamp mascot")
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = .brandTeal
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(color, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(Color.brandNavy)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandNavy, lineWidth: 3))
            .offset(y: configuration.isPressed ? 3 : 0)
            .shadow(color: .brandNavy, radius: 0, y: configuration.isPressed ? 0 : 4)
    }
}

struct FlowDiagram: View {
    let boxes: [String]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(boxes.enumerated()), id: \.offset) { i, b in
                    if i > 0 { Image(systemName: "arrow.right").foregroundStyle(.secondary) }
                    Text(b).font(.footnote.weight(.semibold)).multilineTextAlignment(.center)
                        .padding(10).frame(minWidth: 80)
                        .background([Color.brandTeal, .brandLime, .brandYellow][i % 3].opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}
