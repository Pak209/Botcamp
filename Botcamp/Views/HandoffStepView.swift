import SwiftUI
import UIKit
import BotcampCore

/// Option 3 from the plan: copy the prompt, open the user's own AI app, come back and self-check.
/// No API keys, no server, no grading. Plain-text app names only.
struct HandoffStepView: View {
    let step: Handoff
    let onResult: (Bool) -> Void
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var copied = false
    @State private var leftApp = false
    @State private var ticked = Set<Int>()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                SargeByte(pose: .thinking, size: 70)
                StepTitle(text: "Hands-on mission")
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            Text(step.intro).fixedSize(horizontal: false, vertical: true)
            Text(step.prompt)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
            Text("Copy & open in your AI app, e.g.").font(.subheadline.bold())
            ForEach(AIApp.all) { app in
                Button("Copy & open \(app.name)") { copyAndOpen(app) }.buttonStyle(ChunkyButtonStyle(color: .brandYellow))
            }
            Button(copied ? "Copied ✓" : "Just copy the prompt") { copy() }.frame(maxWidth: .infinity)

            if leftApp || copied {
                Divider().padding(.vertical, 4)
                Text("Back already? Check yourself:").font(.headline)
                ForEach(step.checklist.indices, id: \.self) { i in
                    Button { ticked.formSymmetricDifference([i]) } label: {
                        Label {
                            Text(step.checklist[i])
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } icon: {
                            Image(systemName: ticked.contains(i) ? "checkmark.square.fill" : "square")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }.foregroundStyle(Color.brandNavy)
                }
                Button("Mission complete") { onResult(true) }
                    .buttonStyle(ChunkyButtonStyle(color: .brandLime))
                    .disabled(!Grader.check(step, ticked: ticked))
            }
            Text("Botcamp isn't affiliated with these apps. Use whichever assistant you like.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: scenePhase) { _, phase in if phase == .background { leftApp = true } }
    }

    private func copy() { UIPasteboard.general.string = step.prompt; copied = true }

    private func copyAndOpen(_ app: AIApp) {
        copy()
        guard let appURL = URL(string: app.appURL), let web = URL(string: app.webURL) else { return }
        // Falls back to the website when the app isn't installed.
        if UIApplication.shared.canOpenURL(appURL) { openURL(appURL) } else { openURL(web) }
    }
}
