import SwiftUI
import SwiftData

struct RootTabView: View {
    @Query private var profiles: [PlayerProfile]
    @State private var showOnboarding = false
    var body: some View {
        TabView {
            HomePathView().tabItem { Label("Learn", systemImage: "map.fill") }
            CapstoneView().tabItem { Label("Plan", systemImage: "target") }
            GlossaryView().tabItem { Label("Glossary", systemImage: "book.closed.fill") }
            ProfileView().tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .onAppear { showOnboarding = !(profiles.first?.hasOnboarded ?? false) }
        .fullScreenCover(isPresented: $showOnboarding) { OnboardingView() }
    }
}
