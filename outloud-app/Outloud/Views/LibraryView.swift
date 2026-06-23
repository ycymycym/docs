import SwiftUI
import UniformTypeIdentifiers
import ReaderCore

/// Home screen: recent documents (local only) + entry points to import a PDF or
/// paste a link/text.
struct LibraryView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var library: LibraryStore
    @State private var showPDFImporter = false
    @State private var showPasteSheet = false

    var body: some View {
        List {
            Section {
                Button { showPDFImporter = true } label: {
                    Label("Open a PDF", systemImage: "doc.fill")
                }
                Button { showPasteSheet = true } label: {
                    Label("Paste a link or text", systemImage: "link")
                }
            }

            if !library.documents.isEmpty {
                Section("Recent") {
                    ForEach(library.documents) { doc in
                        Button { env.openExisting(doc) } label: {
                            DocumentRow(doc: doc)
                        }
                        .tint(.primary)
                    }
                    .onDelete { indexSet in
                        indexSet.map { library.documents[$0].id }.forEach(library.delete)
                    }
                }
            }
        }
        .navigationTitle("Outloud")
        .overlay {
            if library.documents.isEmpty {
                ContentUnavailableView(
                    "Listen to anything",
                    systemImage: "headphones",
                    description: Text("Share a PDF or web page to Outloud, or open one here. It reads aloud — fully on your device, offline.")
                )
            }
        }
        .fileImporter(isPresented: $showPDFImporter,
                      allowedContentTypes: [.pdf],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                env.importPDF(at: url)
            }
        }
        .sheet(isPresented: $showPasteSheet) {
            PasteEntryView()
        }
    }
}

private struct DocumentRow: View {
    let doc: ReaderDocument

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title).font(.body).lineLimit(1)
                Text(doc.lastOpenedAt, style: .relative)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if doc.resumeSentenceIndex > 0 {
                Image(systemName: "arrow.clockwise.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var icon: String {
        switch doc.sourceKind {
        case .pdf: return "doc.fill"
        case .web: return "safari.fill"
        case .plainText: return "text.alignleft"
        }
    }
}

/// "Paste a link / paste text" entry sheet.
private struct PasteEntryView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $text)
                    .padding(8)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Paste a URL or any text…")
                                .foregroundStyle(.secondary)
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .navigationTitle("Paste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listen") { submit() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed),
           let scheme = url.scheme, scheme.hasPrefix("http"),
           !trimmed.contains(" ") {
            env.importURL(url)
        } else {
            env.importText(trimmed, title: nil)
        }
        dismiss()
    }
}
