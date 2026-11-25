import Foundation
import SwiftUI
import Combine
import PDFKit
import ZIPFoundation

@MainActor
class BookStore: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let booksKey = "ManhwaReaderBooks"
    private let fileManager = FileManager.default

    init() {
        loadBooks()
    }

    func loadBooks() {
        isLoading = true
        defer { isLoading = false }

        guard let data = UserDefaults.standard.data(forKey: booksKey) else {
            books = []
            return
        }

        do {
            let decoder = JSONDecoder()
            books = try decoder.decode([Book].self, from: data)
        } catch {
            errorMessage = "Failed to load books: \(error.localizedDescription)"
            books = []
        }
    }

    func saveBooks() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(books)
            UserDefaults.standard.set(data, forKey: booksKey)
        } catch {
            errorMessage = "Failed to save books: \(error.localizedDescription)"
        }
    }

    func addBook(_ book: Book) {
        books.insert(book, at: 0)
        saveBooks()
    }

    func removeBook(_ book: Book) {
        books.removeAll { $0.id == book.id }
        saveBooks()
    }

    func updateBook(_ book: Book) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
            saveBooks()
        }
    }

    func updateLastReadPage(for bookId: UUID, page: Int) {
        if let index = books.firstIndex(where: { $0.id == bookId }) {
            var book = books[index]
            book = Book(
                id: book.id,
                title: book.title,
                author: book.author,
                format: book.format,
                fileURL: book.fileURL,
                coverImageData: book.coverImageData,
                lastReadPage: page,
                totalPages: book.totalPages,
                dateAdded: book.dateAdded,
                readingDirection: book.readingDirection
            )
            books[index] = book
            saveBooks()
        }
    }

    func importFile(from url: URL) async throws -> Book {
        let format = BookFormat.from(url: url) ?? .pdf
        let title = url.deletingPathExtension().lastPathComponent

        // Copy file to app's documents directory for persistent access
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsURL.appendingPathComponent(url.lastPathComponent)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: url, to: destinationURL)

        // Start security-scoped resource access
        let isSecure = destinationURL.startAccessingSecurityScopedResource()
        defer {
            if isSecure {
                destinationURL.stopAccessingSecurityScopedResource()
            }
        }

        // Extract cover image
        let coverData = try await extractCoverImage(from: destinationURL, format: format)

        // Count pages
        let pageCount = try await countPages(in: destinationURL, format: format)

        let book = Book(
            title: title,
            author: nil,
            format: format,
            fileURL: destinationURL,
            coverImageData: coverData,
            totalPages: pageCount
        )

        addBook(book)
        return book
    }

    private func extractCoverImage(from url: URL, format: BookFormat) async throws -> Data? {
        switch format {
        case .pdf:
            return try await extractPDFCover(url: url)
        case .cbz, .cb7, .cbr:
            return try await extractCBZCover(url: url)
        }
    }

    private func extractPDFCover(url: URL) async throws -> Data? {
        let isSecure = url.startAccessingSecurityScopedResource()
        defer {
            if isSecure {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else {
            return nil
        }

        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(pageRect)
            page.draw(with: .mediaBox, to: context.cgContext)
        }

        return image.jpegData(compressionQuality: 0.7)
    }

    private func extractCBZCover(url: URL) async throws -> Data? {
        let isSecure = url.startAccessingSecurityScopedResource()
        defer {
            if isSecure {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let archive = try Archive(url: url, accessMode: .read)
        let imageEntries = archive.filter { entry in
            let lower = entry.path.lowercased()
            return lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") ||
                   lower.hasSuffix(".png") || lower.hasSuffix(".webp") ||
                   lower.hasSuffix(".bmp") || lower.hasSuffix(".gif")
        }.sorted { $0.path < $1.path }

        guard let firstEntry = imageEntries.first else { return nil }

        var imageData = Data()
        try archive.extract(firstEntry) { data in
            imageData.append(data)
        }

        return imageData
    }

    private func countPages(in url: URL, format: BookFormat) async throws -> Int {
        switch format {
        case .pdf:
            return try await countPDFPages(url: url)
        case .cbz, .cb7, .cbr:
            return try await countCBZPages(url: url)
        }
    }

    private func countPDFPages(url: URL) async throws -> Int {
        let isSecure = url.startAccessingSecurityScopedResource()
        defer {
            if isSecure {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: url) else {
            return 0
        }

        return document.pageCount
    }

    private func countCBZPages(url: URL) async throws -> Int {
        let isSecure = url.startAccessingSecurityScopedResource()
        defer {
            if isSecure {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let archive = try Archive(url: url, accessMode: .read)
        let count = archive.filter { entry in
            let lower = entry.path.lowercased()
            return lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") ||
                   lower.hasSuffix(".png") || lower.hasSuffix(".webp") ||
                   lower.hasSuffix(".bmp") || lower.hasSuffix(".gif")
        }.count

        return count
    }
}