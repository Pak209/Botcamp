import SwiftUI
import SwiftData
import BotcampCore

/// Completion certificate, rendered to a shareable PNG with ImageRenderer.
struct CertificateCard: View {
    let name: String
    let rank: Rank
    let xp: Int
    let date: Date
    var body: some View {
        VStack(spacing: 14) {
            Text("BOTCAMP: LEARN AI").font(.caption.weight(.heavy)).tracking(3).foregroundStyle(Color.brandOlive)
            Text("Certificate of Completion").font(.system(size: 30, weight: .heavy)).foregroundStyle(Color.brandNavy)
            Text("This certifies that").font(.subheadline)
            Text(name.isEmpty ? "A Botcamp Graduate" : name).font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(Color.brandTeal)
            Text("completed all 10 units, from AI basics to subagent teams.").font(.subheadline).multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Image("mascot-cheer").resizable().scaledToFit().frame(width: 110, height: 110)
                Image(rank.badgeAsset).resizable().scaledToFit().frame(width: 90, height: 90)
            }
            Text("\(rank.title) · \(xp) XP · \(date.formatted(date: .long, time: .omitted))").font(.footnote.weight(.semibold))
            Text("Signed, Sarge Byte").font(.footnote.italic()).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 600, height: 760)
        .background(Color.brandCream)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.brandNavy, lineWidth: 8).padding(10))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.brandYellow, lineWidth: 3).padding(24))
    }
}

struct CertificateView: View {
    @Environment(CourseStore.self) private var content
    @Query private var profiles: [PlayerProfile]
    @Query private var records: [LessonRecord]
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var rendered: Image?

    private var completed: Set<String> { Set(records.map(\.lessonId)) }

    var body: some View {
        let earned = Certificate.isEarned(course: content.course, completed: completed)
        let p = profiles.first
        let card = CertificateCard(name: name, rank: Rank.forXP(p?.totalXP ?? 0), xp: p?.totalXP ?? 0,
                                   date: records.map(\.completedAt).max() ?? .now)
        ScrollView {
            VStack(spacing: 16) {
                if earned {
                    TextField("Name on certificate", text: $name).textFieldStyle(.roundedBorder)
                        .onSubmit { save() }
                    card.scaleEffect(0.55).frame(width: 330, height: 420)
                    if let rendered {
                        ShareLink(item: rendered, preview: SharePreview("Botcamp certificate", image: rendered)) {
                            Label("Share certificate", systemImage: "square.and.arrow.up")
                        }.buttonStyle(ChunkyButtonStyle())
                    }
                } else {
                    SargeByte(pose: .thinking, size: 120)
                    Text("Finish all 10 units to earn your certificate.").font(.headline)
                    XPBar(to: Certificate.progress(course: content.course, completed: completed),
                          label: "\(Int(Certificate.progress(course: content.course, completed: completed) * 100))% of lessons done")
                }
            }
            .padding()
        }
        .navigationTitle("Certificate")
        .onAppear { name = p?.playerName ?? ""; render(card) }
        .onDisappear { save() }
        .onChange(of: name) { _, _ in render(CertificateCard(name: name, rank: card.rank, xp: card.xp, date: card.date)) }
    }

    private func save() { profiles.first?.playerName = name; try? context.save() }

    @MainActor private func render(_ card: CertificateCard) {
        let r = ImageRenderer(content: card); r.scale = 2
        if let ui = r.uiImage { rendered = Image(uiImage: ui) }
    }
}
