import SwiftUI

// MARK: - App Entry Point
@main
struct SwiftBookApp: App {
    @StateObject private var bookManager = BookManager()
    @StateObject private var readingStatsManager = ReadingStatsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bookManager)
                .environmentObject(readingStatsManager)
                .onOpenURL { url in
                    // Handle EPUB file opened from Files app
                    Task {
                        await bookManager.importEPUB(from: url)
                    }
                }
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var bookManager: BookManager
    @EnvironmentObject var readingStatsManager: ReadingStatsManager

    var body: some View {
        TabView {
            LibraryView()
                .environmentObject(bookManager)
                .tabItem {
                    Label("书库", systemImage: "books.vertical.fill")
                }

            ReadingStatsView()
                .environmentObject(bookManager)
                .environmentObject(readingStatsManager)
                .tabItem {
                    Label("阅读进度", systemImage: "chart.bar.fill")
                }
        }
    }
}
