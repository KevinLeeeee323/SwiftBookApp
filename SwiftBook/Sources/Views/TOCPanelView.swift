import SwiftUI

// MARK: - Table of Contents Panel
struct TOCPanelView: View {
    let chapters: [Chapter]
    @Binding var currentPage: Int
    @Binding var isPresented: Bool
    @Binding var isControlsShown: Bool

    var body: some View {
        VStack(spacing: 0) {
        
//            Spacer()

            VStack(spacing: 0) {
                // Handle
                handleBar
                    .padding(.top, 8)

                // Title
                HStack {
                    Text("目录")
                        .font(.headline)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    currentPage = max(0, chapter.pageOffset)
                                    isPresented = false
                                    isControlsShown = true
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(chapter.title)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Text("\(max(1, chapter.pageOffset + 1))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                        .frame(width: 44, alignment: .trailing)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.03))
                            }
                            .buttonStyle(.plain)

                            if index < chapters.count - 1 {
                                Divider().padding(.leading, 24)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: -6)
            )
            .frame(maxHeight: UIScreen.main.bounds.height * 0.60)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Color.clear)
        .onTapGesture {
            withAnimation { isPresented = false }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // MARK: - Handle Bar
    private var handleBar: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 36, height: 5)
    }
}
