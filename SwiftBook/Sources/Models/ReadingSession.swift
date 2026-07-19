import Foundation

// MARK: - Reading Session Model
struct ReadingSession: Codable, Identifiable {
    let id: UUID
    let bookId: UUID
    let date: Date       // when the session occurred (used for daily aggregation)
    let duration: TimeInterval  // seconds

    init(id: UUID = UUID(), bookId: UUID, date: Date = Date(), duration: TimeInterval) {
        self.id = id
        self.bookId = bookId
        self.date = date
        self.duration = duration
    }
}
