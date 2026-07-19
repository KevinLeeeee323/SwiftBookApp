import Foundation
import SwiftUI

// MARK: - Reading Stats Manager
@MainActor
final class ReadingStatsManager: ObservableObject {
    @Published var sessions: [ReadingSession] = []
    @Published var dailyGoalMinutes: Int = 30
    @Published var todayDuration: TimeInterval = 0
    @Published var streakDays: Int = 0
    @Published var longestStreak: Int = 0
    @Published var booksFinishedThisYear: Int = 0

    private let fileManager = FileManager.default
    private let calendar = Calendar.current

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var sessionsURL: URL {
        documentsURL.appendingPathComponent("reading_sessions.json")
    }

    private let goalDefaultsKey = "reading_goal_minutes"

    init() {
        loadSessions()
        loadGoal()
    }

    // MARK: - Add Session
    func addSession(bookId: UUID, duration: TimeInterval) {
        guard duration > 0 else { return }
        let session = ReadingSession(bookId: bookId, date: Date(), duration: duration)
        sessions.append(session)
        saveSessions()
        recalculateStats()
    }

    // MARK: - Daily Goal
    func setDailyGoal(minutes: Int) {
        dailyGoalMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: goalDefaultsKey)
    }

    // MARK: - Recalculate Stats
    func recalculateStats(books: [Book] = []) {
        todayDuration = calculateTodayDuration()
        streakDays = calculateStreak()
        longestStreak = calculateLongestStreak()
        if !books.isEmpty {
            booksFinishedThisYear = calculateBooksFinishedThisYear(books: books)
        }
    }

    // MARK: - Today's Duration
    private func calculateTodayDuration() -> TimeInterval {
        let todayStart = calendar.startOfDay(for: Date())
        return sessions
            .filter { $0.date >= todayStart }
            .reduce(0) { $0 + $1.duration }
    }

    // MARK: - Reading Streak (consecutive days meeting daily goal)
    private func calculateStreak() -> Int {
        let goalSeconds = Double(dailyGoalMinutes) * 60
        return consecutiveGoalDays(endingAt: Date(), goalSeconds: goalSeconds)
    }

    // MARK: - Longest Streak Ever
    private func calculateLongestStreak() -> Int {
        let goalSeconds = Double(dailyGoalMinutes) * 60
        guard !sessions.isEmpty else { return 0 }

        // Collect all unique days that have sessions
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !uniqueDays.isEmpty else { return 0 }

        var best = 0
        var current = 0
        var prevDay: Date? = nil

        for day in uniqueDays {
            let dayStart = day
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let total = sessions
                .filter { $0.date >= dayStart && $0.date < dayEnd }
                .reduce(0) { $0 + $1.duration }

            if total >= goalSeconds {
                if let prev = prevDay, calendar.isDate(day, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: prev)!) {
                    current += 1
                } else {
                    current = 1
                }
                best = max(best, current)
            } else {
                current = 0
            }
            prevDay = day
        }
        return best
    }

    // Shared helper: count consecutive days meeting goal, walking backward from endDate
    private func consecutiveGoalDays(endingAt endDate: Date, goalSeconds: Double) -> Int {
        var count = 0
        let today = calendar.startOfDay(for: endDate)

        // Check the end date itself
        let endDayStart = today
        let endDayEnd = calendar.date(byAdding: .day, value: 1, to: endDayStart)!
        let endTotal = sessions
            .filter { $0.date >= endDayStart && $0.date < endDayEnd }
            .reduce(0) { $0 + $1.duration }
        let metToday = endTotal >= goalSeconds

        // If end date goal not met, start from yesterday
        var checkDate = metToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        while true {
            let dayStart = checkDate
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let daySessions = sessions.filter { $0.date >= dayStart && $0.date < dayEnd }
            let total = daySessions.reduce(0) { $0 + $1.duration }

            if total >= goalSeconds {
                count += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return count
    }

    // MARK: - Books Finished This Year
    private func calculateBooksFinishedThisYear(books: [Book]) -> Int {
        let currentYear = calendar.component(.year, from: Date())
        return books.filter { book in
            guard book.isFinished, let date = book.finishedDate else { return false }
            return calendar.component(.year, from: date) == currentYear
        }.count
    }

    // MARK: - Persistence
    private func loadSessions() {
        guard fileManager.fileExists(atPath: sessionsURL.path) else { return }
        do {
            let data = try Data(contentsOf: sessionsURL)
            sessions = try JSONDecoder().decode([ReadingSession].self, from: data)
            recalculateStats()
        } catch {
            print("Failed to load reading sessions: \(error)")
            sessions = []
        }
    }

    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: sessionsURL)
        } catch {
            print("Failed to save reading sessions: \(error)")
        }
    }

    private func loadGoal() {
        let saved = UserDefaults.standard.integer(forKey: goalDefaultsKey)
        if saved > 0 {
            dailyGoalMinutes = saved
        }
    }
}
