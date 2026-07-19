import SwiftUI

// MARK: - Reading Stats View
struct ReadingStatsView: View {
    @EnvironmentObject var bookManager: BookManager
    @EnvironmentObject var readingStatsManager: ReadingStatsManager
    @State private var showGoalPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if readingStatsManager.sessions.isEmpty && booksFinishedThisYear == 0 {
                    emptyStatsView
                } else {
                    VStack(spacing: 20) {
                        todayReadingCard
                        statsCards
                        goalSettingsCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("阅读进度")
            .onAppear {
                readingStatsManager.recalculateStats(books: bookManager.books)
            }
        }
    }

    // MARK: - Empty State
    private var emptyStatsView: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 100)

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 140, height: 140)

                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.linearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }

            VStack(spacing: 8) {
                Text("还没有阅读数据")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("开始阅读你的第一本书吧\n阅读时长和进度会自动记录在这里")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Today's Reading Card
    private var todayReadingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.accentColor)
                Text("今日阅读")
                    .font(.headline)
                Spacer()
            }

            // Time display
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(formattedMinutes(from: readingStatsManager.todayDuration))
                    .font(.system(size: 34, weight: .bold))
                Text("/ \(readingStatsManager.dailyGoalMinutes) 分钟")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Linear progress bar
            progressBar

            // Goal status text
            Text(goalStatusText)
                .font(.caption)
                .foregroundColor(goalReached ? .orange : .secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        let goalSeconds = Double(readingStatsManager.dailyGoalMinutes) * 60
        let progress = goalSeconds > 0 ? min(readingStatsManager.todayDuration / goalSeconds, 1.0) : 0

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 8)

                // Filled portion
                Capsule()
                    .fill(goalReached ? Color.orange : Color.accentColor)
                    .frame(width: max(geo.size.width * progress, progress > 0 ? 8 : 0), height: 8)
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: 8)
    }

    // MARK: - Stats Cards (Vertical Stack)
    private var statsCards: some View {
        VStack(spacing: 12) {
            // Streak card
            streakCard

            // Books finished this year
            statCard(
                icon: "book.closed.fill",
                iconColor: .blue,
                title: "本年读完",
                value: "\(booksFinishedThisYear)",
                unit: "本"
            )
        }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }

                Text("连续阅读")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(readingStatsManager.streakDays)")
                        .font(.system(size: 32, weight: .bold))
                    Text("天")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Longest streak
            if readingStatsManager.longestStreak > 0 {
                Divider()
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("最长连续记录：\(readingStatsManager.longestStreak) 天")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }

    private func statCard(icon: String, iconColor: Color, title: String, value: String, unit: String) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }

            // Title
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Value + Unit
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }

    // MARK: - Goal Settings Card
    private var goalSettingsCard: some View {
        let goalHours = readingStatsManager.dailyGoalMinutes / 60
        let goalMins = readingStatsManager.dailyGoalMinutes % 60

        return VStack(alignment: .leading, spacing: 0) {
            // Header row (always visible)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showGoalPicker.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.accentColor)
                    Text("每日目标")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formattedGoal(hours: goalHours, mins: goalMins))
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    Image(systemName: showGoalPicker ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Collapsible wheel pickers
            if showGoalPicker {
                HStack(spacing: 0) {
                    // Hours picker
                    Picker("小时", selection: Binding(
                        get: { readingStatsManager.dailyGoalMinutes / 60 },
                        set: { newHour in
                            let mins = readingStatsManager.dailyGoalMinutes % 60
                            let total = newHour * 60 + mins
                            readingStatsManager.setDailyGoal(minutes: max(5, min(total, 24 * 60)))
                        }
                    )) {
                        ForEach(0...24, id: \.self) { hour in
                            Text("\(hour) 小时").tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 120)

                    // Minutes picker (step 5)
                    Picker("分钟", selection: Binding(
                        get: { readingStatsManager.dailyGoalMinutes % 60 },
                        set: { newMin in
                            let hours = readingStatsManager.dailyGoalMinutes / 60
                            var total = hours * 60 + newMin
                            // Prevent 0h 0m: if both zero, snap to 5 min
                            if total == 0 {
                                total = 5
                            }
                            total = min(total, 24 * 60)
                            readingStatsManager.setDailyGoal(minutes: total)
                        }
                    )) {
                        ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { min in
                            Text("\(min) 分钟").tag(min)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 120)
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }

    // MARK: - Computed Helpers
    private var goalReached: Bool {
        let goalSeconds = Double(readingStatsManager.dailyGoalMinutes) * 60
        return readingStatsManager.todayDuration >= goalSeconds
    }

    private var goalStatusText: String {
        let goalSeconds = Double(readingStatsManager.dailyGoalMinutes) * 60
        guard goalSeconds > 0 else { return "" }
        if readingStatsManager.todayDuration >= goalSeconds {
            return "目标已达成！🎉"
        }
        let pct = Int(readingStatsManager.todayDuration / goalSeconds * 100)
        return "已达成目标的 \(pct)%"
    }

    private var booksFinishedThisYear: Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        return bookManager.books.filter { book in
            guard book.isFinished, let date = book.finishedDate else { return false }
            return Calendar.current.component(.year, from: date) == currentYear
        }.count
    }

    private func formattedMinutes(from seconds: TimeInterval) -> String {
        let mins = max(0, Int(seconds / 60))
        return "\(mins)"
    }

    private func formattedGoal(hours: Int, mins: Int) -> String {
        if hours == 0 {
            return "\(mins) 分钟"
        } else if mins == 0 {
            return "\(hours) 小时"
        } else {
            return "\(hours) 小时 \(mins) 分钟"
        }
    }
}
