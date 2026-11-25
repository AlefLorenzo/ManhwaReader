import Foundation
import SwiftUI

enum BookFormat: String, Codable, CaseIterable {
    case cbz = "cbz"
    case pdf = "pdf"
    case cb7 = "cb7"
    case cbr = "cbr"

    var displayName: String {
        rawValue.uppercased()
    }

    static func from(url: URL) -> BookFormat? {
        let ext = url.pathExtension.lowercased()
        return BookFormat.allCases.first { $0.rawValue == ext }
    }
}

struct Book: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let author: String?
    let format: BookFormat
    let fileURL: URL
    let coverImageData: Data?
    let lastReadPage: Int
    let totalPages: Int
    let dateAdded: Date
    let readingDirection: ReadingDirection

    init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        format: BookFormat,
        fileURL: URL,
        coverImageData: Data? = nil,
        lastReadPage: Int = 0,
        totalPages: Int = 0,
        dateAdded: Date = Date(),
        readingDirection: ReadingDirection = .rightToLeft
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.format = format
        self.fileURL = fileURL
        self.coverImageData = coverImageData
        self.lastReadPage = lastReadPage
        self.totalPages = totalPages
        self.dateAdded = dateAdded
        self.readingDirection = readingDirection
    }

    var coverImage: Image? {
        guard let data = coverImageData, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    var formattedDateAdded: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dateAdded)
    }
}

enum ReadingDirection: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case leftToRight = "ltr"
    case rightToLeft = "rtl"
    case vertical = "vertical"

    var displayName: String {
        switch self {
        case .leftToRight: return "Left to Right"
        case .rightToLeft: return "Right to Left (Manhwa)"
        case .vertical: return "Vertical Scroll"
        }
    }
}