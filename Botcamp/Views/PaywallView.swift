import SwiftUI

/// Pro paywall stub. Uses Apple IAP only; no external links or web pricing (guideline 3.1.1).
struct PaywallView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 18) {
            SargeByte(pose: .cheer, size: 140).padding(.top, 30)
            Text("Botcamp Pro").font(.largeTitle.weight(.heavy))
            Text("Level up past the basics.").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(["Projects, memory and media units", "Agents and coding agents", "Automations and subagent teams", "Plan-your-first-project capstone", "One-time unlock. No subscription."], id: \.self) {
                    Label($0, systemImage: "checkmark.seal.fill")
                }
            }.padding().background(.white, in: RoundedRectangle(cornerRadius: 16))
            Spacer()
            if pro.hasPro {
                Label("You have Pro", systemImage: "star.fill").font(.headline)
                Button("Done") { dismiss() }.buttonStyle(ChunkyButtonStyle())
            } else {
                Button(pro.product.map { "Unlock Pro · \($0.displayPrice)" } ?? "Unlock Pro") { Task { await pro.purchase() } }
                    .buttonStyle(ChunkyButtonStyle(color: .brandLime)).disabled(pro.isBusy)
                Button("Restore Purchases") { Task { await pro.restore() } }.font(.footnote)
            }
            if let e = pro.errorMessage { Text(e).font(.footnote).foregroundStyle(.red) }
        }
        .padding().background(Color.brandCream.ignoresSafeArea())
        .onChange(of: pro.hasPro) { _, has in if has { dismiss() } }
    }
}
