import SwiftUI
import SwiftData
import BotcampCore

@main
struct BotcampApp: App {
    @State private var content = CourseStore()
    @State private var pro = ProStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(content)
                .environment(pro)
                .task { await pro.start() }
                .tint(.brandTeal)
        }
        .modelContainer(for: [PlayerProfile.self, LessonRecord.self, MissedQuestion.self])
    }
}
