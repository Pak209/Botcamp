import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomePathView().tabItem { Label("Learn", systemImage: "map.fill") }
            GlossaryView().tabItem { Label("Glossary", systemImage: "book.closed.fill") }
            ProfileView().tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
    }
}
