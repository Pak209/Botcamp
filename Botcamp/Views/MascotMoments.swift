import SwiftUI
import BotcampCore

/// Level-up burst: rays + confetti dots radiating from Sarge (port of anim-level-up.svg).
struct LevelUpBurst: View {
    var rank: Rank
    @State private var go = false
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                Capsule().fill(i.isMultiple(of: 2) ? Color.brandYellow : .brandLime)
                    .frame(width: 8, height: go ? 46 : 6)
                    .offset(y: go ? -120 : -40)
                    .rotationEffect(.degrees(Double(i) * 30))
                    .opacity(go ? 0 : 1)
            }
            ForEach(0..<10, id: \.self) { i in
                Circle().fill([Color.brandPink, .brandTeal, .brandOrange][i % 3]).frame(width: 10, height: 10)
                    .offset(y: go ? -150 : 0).rotationEffect(.degrees(Double(i) * 36 + 18))
                    .opacity(go ? 0 : 1)
            }
            VStack(spacing: 8) {
                SargeByte(pose: .cheer, size: 150).scaleEffect(go ? 1 : 0.6)
                Image(rank.badgeAsset).resizable().scaledToFit().frame(width: 72, height: 72).scaleEffect(go ? 1 : 0.2)
                Text("Promoted to \(rank.title)!")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Color.brandNavy)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.1)) { go = true } }
        .accessibilityElement(children: .ignore).accessibilityLabel("Rank up: \(rank.title)")
    }
}

/// Flickering streak flame (port of anim-streak-flame.svg). Grey and still when the streak is 0.
struct StreakFlame: View {
    var streak: Int
    var size: CGFloat = 22
    @State private var flicker = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 3) {
            ZStack {
                Image(systemName: "flame.fill").font(.system(size: size)).foregroundStyle(streak > 0 ? Color.brandOrange : .gray)
                if streak > 0 {
                    Image(systemName: "flame.fill").font(.system(size: size * 0.55)).foregroundStyle(Color.brandYellow).offset(y: size * 0.15)
                }
            }
            .scaleEffect(x: flicker ? 0.92 : 1.05, y: flicker ? 1.08 : 0.96, anchor: .bottom)
            .animation(streak > 0 ? .easeInOut(duration: 0.35).repeatForever(autoreverses: true) : .default, value: flicker)
            Text("\(streak)").font(.subheadline.bold()).foregroundStyle(Color.brandOrange)
        }
        .onAppear { flicker = streak > 0 && !reduceMotion }
        .accessibilityElement(children: .ignore).accessibilityLabel("\(streak) day streak")
    }
}

/// Chunky XP bar that fills from `from` to `to` (0…1) with a shine sweep (port of anim-xp-fill.svg).
struct XPBar: View {
    var from: Double = 0
    var to: Double
    var label: String? = nil
    @State private var shown: Double = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.brandNavy.opacity(0.15))
                    Capsule().fill(LinearGradient(colors: [.brandLime, .brandTeal], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(14, g.size.width * shown))
                    Capsule().fill(.white.opacity(0.45)).frame(width: max(8, g.size.width * shown - 12), height: 4).offset(x: 6, y: -4)
                }
                .overlay(Capsule().stroke(Color.brandNavy, lineWidth: 2))
            }
            .frame(height: 18)
            if let label {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            shown = from
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) { shown = min(1, max(0, to)) }
        }
        .onChange(of: to) { _, v in withAnimation(.easeOut(duration: 0.8)) { shown = min(1, max(0, v)) } }
        .accessibilityElement(children: .ignore).accessibilityValue("\(Int(to * 100)) percent")
    }
}

/// Sleeping Sarge with drifting Zzz for a broken streak.
struct SleepingSarge: View {
    var size: CGFloat = 84
    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SargeByte(pose: .sleeping, size: size)
            ForEach(0..<3, id: \.self) { i in
                Text("z").font(.system(size: size * (0.14 + 0.05 * CGFloat(i)), weight: .heavy)).foregroundStyle(Color.brandNavy)
                    .offset(x: drift ? CGFloat(10 + i * 8) : 0, y: drift ? CGFloat(-20 - i * 14) : 0)
                    .opacity(drift ? 0 : 0.9)
                    .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 0.6), value: drift)
            }
        }
        .onAppear { drift = !reduceMotion }
        .accessibilityLabel("Sarge Byte is asleep. Your streak ended.")
    }
}
