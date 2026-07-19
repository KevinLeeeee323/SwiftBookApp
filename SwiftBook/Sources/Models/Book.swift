import Foundation
import SwiftUI

// MARK: - Book Model
struct Book: Identifiable, Codable, Hashable, Transferable {
    let id: UUID
    var title: String
    var author: String
    var coverImageData: Data?
    var filePath: String          // relative path within app's documents
    var fileName: String
    var totalPages: Int
    var currentPage: Int
    var lastOpened: Date
    var dateAdded: Date
    var isFinished: Bool = false
    var finishedDate: Date? = nil

    // Chapter-level info (populated during parsing)
    var chapters: [Chapter] = []
    var spine: [String] = []      // ordered list of content file paths (hrefs)
    var manifest: [String: String] = [:] // id → href mapping for resources

    // Non-codable: runtime-only
    var coverImage: Image? {
        guard let data = coverImageData, let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }

    var progressPercent: Int {
        Int(progress * 100)
    }

    // MARK: - Hashable / Equatable (identity based on id only)
    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Transferable (drag & drop support)
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

// MARK: - Chapter
struct Chapter: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var href: String             // path to content file within EPUB
    var playOrder: Int
    var pageOffset: Int          // starting page index within the book
    var pageCount: Int           // number of pages in this chapter

    init(id: UUID = UUID(), title: String, href: String, playOrder: Int, pageOffset: Int = 0, pageCount: Int = 0) {
        self.id = id
        self.title = title
        self.href = href
        self.playOrder = playOrder
        self.pageOffset = pageOffset
        self.pageCount = pageCount
    }
}

// MARK: - Reading Progress (Codable for persistence)
struct ReadingProgress: Codable {
    var bookId: UUID
    var currentPage: Int
    var totalPages: Int
    var lastOpened: Date
}
