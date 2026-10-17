import SwiftUI
import SwiftData

struct RootTabView: View {
    @Query private var profiles: [PlayerProfile]
    @State private var showOnboarding = false
    @State private var startAfterOnboarding = false
    @State private var autoStartLesson = false
    var body: some View {
        TabView {
            HomePathView(autoStart: $autoStartLesson).tabItem { Label("Learn", systemImage: "map.fill") }
            CapstoneView().tabItem { Label("Plan", systemImage: "target") }
            GlossaryView().tabItem { Label("Glossary", systemImage: "book.closed.fill") }
            ProfileView().tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .onAppear { showOnboarding = !(profiles.first?.hasOnboarded ?? false) }
        // Present the first lesson only after the onboarding cover is fully gone.
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
            if startAfterOnboarding { startAfterOnboarding = false; autoStartLesson = true }
        }) {
            OnboardingView { startNow in startAfterOnboarding = startNow }
        }
    }
}
