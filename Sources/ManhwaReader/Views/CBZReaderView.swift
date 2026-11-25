import SwiftUI
import ZIPFoundation

struct CBZReaderView: View {
    let book: Book
    @Binding var currentPage: Int
    let onPageChange: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var imageNames: [String] = []
    @State private var currentImage: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showControls = true
    @State private var readingDirection: ReadingDirection = .rightToLeft
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading CBZ...")
                        .foregroundColor(.white)
                } else if let errorMessage = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") {
                            loadCBZ()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                } else if let currentImage = currentImage {
                    Image(uiImage: currentImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = min(max(lastScale * value, 0.5), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showControls.toggle()
                            }
                        }
                }

                // Controls overlay
                if showControls && !isLoading && errorMessage == nil {
                    VStack {
                        // Top bar
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }

                            Spacer()

                            Text("Page \(currentPage + 1) of \(imageNames.count)")
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)

                            Spacer()

                            Menu {
                                Picker("Reading Direction", selection: $readingDirection) {
                                    ForEach(ReadingDirection.allCases) { direction in
                                        Text(direction.displayName).tag(direction)
                                    }
                                }
                            } label: {
                                Image(systemName: "textformat.alt")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                        .padding()

                        Spacer()

                        // Bottom page navigator
                        HStack {
                            Button(action: previousPage) {
                                Image(systemName: "chevron.left")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .disabled(currentPage <= 0)

                            Spacer()

                            Slider(
                                value: Binding(
                                    get: { Double(currentPage) },
                                    set: { currentPage = Int($0) }
                                ),
                                in: 0...Double(max(imageNames.count - 1, 0)),
                                step: 1
                            )
                            .accentColor(.white)
                            .frame(width: geometry.size.width * 0.6)

                            Spacer()

                            Button(action: nextPage) {
                                Image(systemName: "chevron.right")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .disabled(currentPage >= imageNames.count - 1)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear {
            loadCBZ()
        }
        .onChange(of: currentPage) { _, newPage in
            loadPage(newPage)
            onPageChange(newPage)
        }
    }

    private func loadCBZ() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let isSecure = book.fileURL.startAccessingSecurityScopedResource()
                defer {
                    if isSecure {
                        book.fileURL.stopAccessingSecurityScopedResource()
                    }
                }

                let archive = try Archive(url: book.fileURL, accessMode: .read)
                let entries = archive.map { $0.path }.filter { path in
                    let lower = path.lowercased()
                    return lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") ||
                           lower.hasSuffix(".png") || lower.hasSuffix(".webp") ||
                           lower.hasSuffix(".bmp") || lower.hasSuffix(".gif")
                }.sorted()

                await MainActor.run {
                    self.imageNames = entries
                    self.isLoading = false
                    self.currentPage = min(self.book.lastReadPage, max(entries.count - 1, 0))
                    self.loadPage(self.currentPage)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load CBZ: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func loadPage(_ page: Int) {
        guard page >= 0 && page < imageNames.count else { return }

        Task {
            do {
                let isSecure = book.fileURL.startAccessingSecurityScopedResource()
                defer {
                    if isSecure {
                        book.fileURL.stopAccessingSecurityScopedResource()
                    }
                }

                let archive = try Archive(url: book.fileURL, accessMode: .read)
                guard let entry = archive[imageNames[page]] else {
                    throw NSError(domain: "CBZReader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Entry not found"])
                }

                var imageData = Data()
                try archive.extract(entry) { data in
                    imageData.append(data)
                }

                if let image = UIImage(data: imageData) {
                    await MainActor.run {
                        self.currentImage = image
                        self.scale = 1.0
                        self.lastScale = 1.0
                        self.offset = .zero
                        self.lastOffset = .zero
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load page: \(error.localizedDescription)"
                }
            }
        }
    }

    private func previousPage() {
        if readingDirection == .rightToLeft {
            nextPage()
        } else {
            if currentPage > 0 {
                currentPage -= 1
            }
        }
    }

    private func nextPage() {
        if readingDirection == .rightToLeft {
            if currentPage > 0 {
                currentPage -= 1
            }
        } else {
            if currentPage < imageNames.count - 1 {
                currentPage += 1
            }
        }
    }
}