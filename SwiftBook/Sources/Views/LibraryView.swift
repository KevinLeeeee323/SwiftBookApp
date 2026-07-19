import SwiftUI
import UniformTypeIdentifiers

// MARK: - Library View (Main Screen)
struct LibraryView: View {
    @EnvironmentObject var bookManager: BookManager
    @State private var showingFileImporter = false
    @State private var selectedBook: Book?
    @State private var navigationPath = NavigationPath()

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                if bookManager.books.isEmpty {
                    emptyLibraryView
                } else {
                    booksGridView
                }
            }
            .navigationTitle("书库")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFileImporter = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if !bookManager.books.isEmpty {
                        Text("\(bookManager.books.count) 本书")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationDestination(for: Book.self) { book in
                ReaderView(book: book)
                    .navigationBarHidden(true)
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.epub],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result: result)
            }
            .overlay {
                if bookManager.isLoading {
                    importProgressOverlay
                }
            }
            .alert("导入错误", isPresented: .constant(bookManager.importError != nil)) {
                Button("确定") { bookManager.importError = nil }
            } message: {
                Text(bookManager.importError ?? "")
            }
        }
    }

    // MARK: - Empty Library
    private var emptyLibraryView: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 100)

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 140, height: 140)

                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.linearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }

            VStack(spacing: 8) {
                Text("你的书库还是空的")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("点击右上角的 + 按钮\n导入 EPUB 格式的电子书")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                showingFileImporter = true
            } label: {
                Label("导入 EPUB", systemImage: "doc.badge.plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    // MARK: - Books Grid
    private var booksGridView: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(bookManager.books.sorted(by: { $0.lastOpened > $1.lastOpened })) { book in
                Button {
                    navigationPath.append(book)
                } label: {
                    // Fold the reading position into the view identity so the card's
                    // progress bar refreshes after open → read → close. `Book` is
                    // Equatable on `id` only, so otherwise SwiftUI can consider the
                    // updated book "unchanged" and skip re-rendering the card.
                    BookCardView(book: book)
                        .id("\(book.id)-\(book.currentPage)-\(book.totalPages)")
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        if book.isFinished {
                            bookManager.markBookAsUnfinished(book)
                        } else {
                            bookManager.markBookAsFinished(book)
                        }
                    } label: {
                        if book.isFinished {
                            Label("标记为未读", systemImage: "book.closed")
                        } else {
                            Label("标记为已读完", systemImage: "checkmark.circle")
                        }
                    }

                    Button(role: .destructive) {
                        withAnimation {
                            bookManager.removeBook(book)
                        }
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Import Progress
    private var importProgressOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.3)

                Text("正在导入...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 6)
            )
        }
    }

    // MARK: - Import Handling
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                for url in urls {
                    await bookManager.importEPUB(from: url)
                }
            }
        case .failure(let error):
            bookManager.importError = error.localizedDescription
        }
    }
}

// MARK: - EPUB UTType extension
extension UTType {
    static var epub: UTType {
        UTType(filenameExtension: "epub") ?? .data
    }
}
