import SwiftUI

// MARK: - Book Card View (for library grid)
struct BookCardView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cover
            coverView
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                Text(book.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Progress bar
                if book.totalPages > 0 && book.currentPage > 0 {
                    progressBar
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Cover View
    @ViewBuilder
    private var coverView: some View {
        if let data = book.coverImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Placeholder cover
            ZStack {
                LinearGradient(
                    colors: placeholderColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 6) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.9))

                    Text(book.title)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        }
    }

    private var placeholderColors: [Color] {
        let seed = abs(book.title.hashValue) % 5
        switch seed {
        case 0: return [Color(red: 0.2, green: 0.5, blue: 0.9), Color(red: 0.3, green: 0.6, blue: 0.95)]
        case 1: return [Color(red: 0.9, green: 0.35, blue: 0.3), Color(red: 0.95, green: 0.5, blue: 0.4)]
        case 2: return [Color(red: 0.2, green: 0.7, blue: 0.4), Color(red: 0.3, green: 0.8, blue: 0.5)]
        case 3: return [Color(red: 0.65, green: 0.3, blue: 0.8), Color(red: 0.75, green: 0.45, blue: 0.85)]
        default: return [Color(red: 0.85, green: 0.55, blue: 0.2), Color(red: 0.9, green: 0.65, blue: 0.3)]
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 3)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * CGFloat(book.progress), height: 3)
            }
        }
        .frame(height: 3)
        .padding(.top, 2)
    }
}
