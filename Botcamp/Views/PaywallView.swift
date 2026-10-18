import SwiftUI

/// Pro paywall stub. Uses Apple IAP only; no external links or web pricing (guideline 3.1.1).
struct PaywallView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 18) {
            ScrollView {
                VStack(spacing: 18) {
                    SargeByte(pose: .cheer, size: 140).padding(.top, 12)
                    Text("Botcamp Pro")
                        .font(.largeTitle.weight(.heavy))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Level up past the basics.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(["Projects, memory and media units", "Agents and coding agents", "Automations and subagent teams", "Plan-your-first-project capstone", "One-time unlock. No subscription."], id: \.self) { line in
                            Label {
                                Text(line)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } icon: {
                                Image(systemName: "checkmark.seal.fill")
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .frame(maxWidth: .infinity)
            }
            if pro.hasPro {
                Label("You have Pro", systemImage: "star.fill").font(.headline)
                Button("Done") { dismiss() }.buttonStyle(ChunkyButtonStyle())
            } else {
                Button(pro.product.map { "Unlock Pro · \($0.displayPrice)" } ?? "Unlock Pro") { Task { await pro.purchase() } }
                    .buttonStyle(ChunkyButtonStyle(color: .brandLime)).disabled(pro.isBusy)
                Button("Restore Purchases") { Task { await pro.restore() } }.font(.footnote)
            }
            if let e = pro.errorMessage {
                Text(e).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding().background(Color.brandCream.ignoresSafeArea())
        .onChange(of: pro.hasPro) { _, has in if has { dismiss() } }
    }
}
