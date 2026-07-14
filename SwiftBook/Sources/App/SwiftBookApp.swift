import SwiftUI

// MARK: - App Entry Point
@main
struct SwiftBookApp: App {
    @StateObject private var bookManager = BookManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bookManager)
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

    var body: some View {
        LibraryView()
            .environmentObject(bookManager)
    }
}
