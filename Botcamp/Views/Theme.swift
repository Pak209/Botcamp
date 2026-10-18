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
        let pressed = configuration.isPressed
        configuration.label
            .font(.headline.weight(.heavy))
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .foregroundStyle(Color.brandNavy)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brandNavy, lineWidth: 3)
            }
            // Depth is a separate shape behind the face. Shadowing the whole
            // control reprints the label a few points lower (doubled text).
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.brandNavy)
                    .offset(y: pressed ? 0 : 4)
            }
            .offset(y: pressed ? 4 : 0)
    }
}

/// Left-to-right row that wraps onto new lines so chips stay on screen.
struct WrappingHStack: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = rows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: item.proposedWidth, height: item.size.height)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Item {
        var index: Subviews.Index
        var size: CGSize
        /// Width passed back to the child so wrapping matches measurement.
        var proposedWidth: CGFloat
    }
    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        let limit = maxWidth.isFinite ? max(maxWidth, 1) : .greatestFiniteMagnitude
        for index in subviews.indices {
            let ideal = subviews[index].sizeThatFits(.unspecified)
            let size: CGSize
            let proposed: CGFloat
            if ideal.width > limit + 0.5 {
                let wrapped = subviews[index].sizeThatFits(ProposedViewSize(width: limit, height: nil))
                let width = min(limit, max(wrapped.width, 1))
                size = CGSize(width: width, height: max(wrapped.height, 1))
                proposed = width
            } else {
                size = CGSize(width: max(ideal.width, 1), height: max(ideal.height, 1))
                proposed = size.width
            }
            let gap: CGFloat = current.items.isEmpty ? 0 : spacing
            if !current.items.isEmpty, current.width + gap + size.width > limit + 0.5 {
                rows.append(current)
                current = Row()
            }
            if !current.items.isEmpty { current.width += spacing }
            current.items.append(Item(index: index, size: size, proposedWidth: proposed))
            current.width += size.width
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

struct FlowDiagram: View {
    let boxes: [String]
    private let tints: [Color] = [.brandTeal, .brandLime, .brandYellow]
    var body: some View {
        WrappingHStack(spacing: 6, lineSpacing: 8) {
            ForEach(Array(boxes.enumerated()), id: \.offset) { i, box in
                FlowChip(title: box, showsArrow: i > 0, tint: tints[i % tints.count])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// One diagram step. The arrow stays with its chip so a wrap doesn't orphan it.
private struct FlowChip: View {
    let title: String
    let showsArrow: Bool
    let tint: Color
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            if showsArrow {
                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.brandNavy)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 0)
                .padding(10)
                .frame(minWidth: 72)
                .background(tint.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
