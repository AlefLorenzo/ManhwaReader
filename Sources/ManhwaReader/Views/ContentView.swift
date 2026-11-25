import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var bookStore = BookStore()
    @State private var showingDocumentPicker = false
    @State private var selectedBook: Book?
    @State private var showingReader = false
    @State private var currentPage = 0
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                if bookStore.books.isEmpty {
                    emptyStateView
                } else {
                    libraryView
                }
            }
            .navigationTitle("Manhwa Reader")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingDocumentPicker = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { urls in
                    Task {
                        for url in urls {
                            do {
                                _ = try await bookStore.importFile(from: url)
                            } catch {
                                errorMessage = error.localizedDescription
                                showingError = true
                            }
                        }
                    }
                }
            }
            .fullScreenCover(item: $selectedBook) { book in
                ReaderContainerView(
                    book: book,
                    currentPage: $currentPage,
                    onDismiss: {
                        selectedBook = nil
                        if let book = bookStore.books.first(where: { $0.id == book.id }) {
                            bookStore.updateLastReadPage(for: book.id, page: currentPage)
                        }
                    }
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Books Yet")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Import CBZ, PDF, or other comic files to start reading")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: { showingDocumentPicker = true }) {
                Label("Import Files", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }

    private var libraryView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140), spacing: 16)
            ], spacing: 16) {
                ForEach(bookStore.books) { book in
                    BookCardView(book: book)
                        .onTapGesture {
                            currentPage = book.lastReadPage
                            selectedBook = book
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                bookStore.removeBook(book)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
        .refreshable {
            bookStore.loadBooks()
        }
    }
}

struct BookCardView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .aspectRatio(2/3, contentMode: .fit)

                if let cover = book.coverImage {
                    cover
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Image(systemName: book.format == .pdf ? "doc.text" : "photo.stack")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                }

                // Format badge
                VStack {
                    HStack {
                        Spacer()
                        Text(book.format.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .padding(4)
                    }
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                if let author = book.author {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Text("Page \(book.lastReadPage + 1) of \(book.totalPages)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(book.formattedDateAdded)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .pdf,
            .zip,
            UTType(filenameExtension: "cbz")!,
            UTType(filenameExtension: "cb7")!,
            UTType(filenameExtension: "cbr")!,
        ]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

struct ReaderContainerView: View {
    let book: Book
    @Binding var currentPage: Int
    let onDismiss: () -> Void

    var body: some View {
        Group {
            switch book.format {
            case .pdf:
                PDFReaderView(
                    book: book,
                    currentPage: $currentPage,
                    onPageChange: { currentPage = $0 }
                )
            case .cbz, .cb7, .cbr:
                CBZReaderView(
                    book: book,
                    currentPage: $currentPage,
                    onPageChange: { currentPage = $0 }
                )
            }
        }
        .onDisappear {
            onDismiss()
        }
    }
}