import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Book Manager
// Manages the book library: import, persistence, and content extraction.
@MainActor
final class BookManager: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var importError: String?

    private let fileManager = FileManager.default
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var booksDirURL: URL {
        let dir = documentsURL.appendingPathComponent("Books", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private var extractedDirURL: URL {
        let dir = documentsURL.appendingPathComponent("Extracted", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private let metadataFilename = "books_metadata.json"

    // MARK: - Init
    init() {
        loadLibrary()
        cleanInbox()
    }

    /// Remove stale files from the Inbox directory (iOS system folder for incoming files)
    private func cleanInbox() {
        let inboxURL = documentsURL.appendingPathComponent("Inbox", isDirectory: true)
        guard let contents = try? fileManager.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil) else {
            return
        }
        for url in contents {
            try? fileManager.removeItem(at: url)
        }
    }

    // MARK: - Import EPUB
    func importEPUB(from url: URL) async {
        isLoading = true
        importError = nil

        defer { isLoading = false }

        do {
            // Start accessing security-scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            // Copy EPUB to app's documents
            let fileName = url.lastPathComponent
            let destURL = booksDirURL.appendingPathComponent(fileName)

            // Remove existing copy if any
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }

            try fileManager.copyItem(at: url, to: destURL)

            // Parse EPUB
            let parser = EPUBParser()
            let parsed = try parser.parse(epubURL: destURL)

            // Extract content files for reading
            let bookDir = extractedDirURL.appendingPathComponent(parsed.title.replacingOccurrences(of: "/", with: "_"))
            if fileManager.fileExists(atPath: bookDir.path) {
                try? fileManager.removeItem(at: bookDir)
            }
            try fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)

            // Extract HTML content files
            var extractedSpine: [String] = []
            for href in parsed.spine {
                if let entryData = try? parsed.zip.read(filename: href) {
                    let destName = href.replacingOccurrences(of: "/", with: "_")
                    let destFile = bookDir.appendingPathComponent(destName)
                    try entryData.write(to: destFile)
                    extractedSpine.append(destName)
                }
            }

            // Extract CSS and images
            for (_, href) in parsed.manifest {
                if let entryData = try? parsed.zip.read(filename: href) {
                    let destName = href.replacingOccurrences(of: "/", with: "_")
                    let destFile = bookDir.appendingPathComponent(destName)
                    try? entryData.write(to: destFile)
                }
            }

            // Create book model
            let book = Book(
                id: UUID(),
                title: parsed.title,
                author: parsed.author,
                coverImageData: parsed.coverImageData,
                filePath: bookDir.lastPathComponent,
                fileName: fileName,
                totalPages: parsed.chapters.count * 15, // rough estimate, refined during reading
                currentPage: 0,
                lastOpened: Date(),
                dateAdded: Date(),
                chapters: parsed.chapters,
                spine: extractedSpine,
                manifest: parsed.manifest
            )

            books.append(book)
            saveLibrary()

            // Clean up the source file from Inbox after successful import
            if url.path.contains("/Inbox/") {
                try? fileManager.removeItem(at: url)
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - Remove book
    func removeBook(_ book: Book) {
        // Remove extracted content
        let bookDir = extractedDirURL.appendingPathComponent(book.filePath)
        try? fileManager.removeItem(at: bookDir)

        // Remove EPUB file
        let epubFile = booksDirURL.appendingPathComponent(book.fileName)
        try? fileManager.removeItem(at: epubFile)

        // Remove from list
        books.removeAll { $0.id == book.id }
        saveLibrary()
    }

    // MARK: - Update reading progress
    func updateProgress(bookId: UUID, page: Int, totalPages: Int) {
        guard let index = books.firstIndex(where: { $0.id == bookId }) else { return }
        books[index].currentPage = page
        books[index].totalPages = totalPages
        books[index].lastOpened = Date()
        saveLibrary()
    }

    // MARK: - Get content URL for a book
    func contentDirectory(for book: Book) -> URL {
        extractedDirURL.appendingPathComponent(book.filePath)
    }

    // MARK: - Persistence
    private var metadataURL: URL {
        documentsURL.appendingPathComponent(metadataFilename)
    }

    private func loadLibrary() {
        guard fileManager.fileExists(atPath: metadataURL.path) else { return }
        do {
            let data = try Data(contentsOf: metadataURL)
            books = try JSONDecoder().decode([Book].self, from: data)
        } catch {
            print("Failed to load library: \(error)")
            books = []
        }
    }

    private func saveLibrary() {
        do {
            let data = try JSONEncoder().encode(books)
            try data.write(to: metadataURL)
        } catch {
            print("Failed to save library: \(error)")
        }
    }
}
