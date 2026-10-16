import SwiftUI
import BotcampCore

struct GlossaryView: View {
    @Environment(CourseStore.self) private var content
    @State private var search = ""
    private var terms: [GlossaryTerm] {
        let all = content.course.glossary.sorted { $0.term < $1.term }
        return search.isEmpty ? all : all.filter { $0.term.localizedCaseInsensitiveContains(search) || $0.definition.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationStack {
            List(terms, id: \.term) { t in
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.term).font(.headline)
                    Text(t.definition).font(.subheadline)
                    if let u = content.course.unit(id: t.unitId) {
                        Text("Learn it in Unit \(u.number): \(u.title)").font(.caption).foregroundStyle(Color.brandTeal)
                    }
                }.padding(.vertical, 4)
            }
            .searchable(text: $search, prompt: "Search terms")
            .navigationTitle("Glossary")
        }
    }
}
