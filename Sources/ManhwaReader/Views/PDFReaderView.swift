import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let book: Book
    @Binding var currentPage: Int
    let onPageChange: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var pdfDocument: PDFDocument?
    @State private var pageCount: Int = 0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showControls = true
    @State private var readingDirection: ReadingDirection = .rightToLeft

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if let pdfDocument = pdfDocument {
                    PDFKitView(
                        document: pdfDocument,
                        currentPage: $currentPage,
                        scale: $scale,
                        offset: $offset,
                        readingDirection: readingDirection
                    )
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
                } else {
                    ProgressView("Loading PDF...")
                        .foregroundColor(.white)
                }

                // Controls overlay
                if showControls {
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

                            Text("Page \(currentPage + 1) of \(pageCount)")
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
                                in: 0...Double(max(pageCount - 1, 0)),
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
                            .disabled(currentPage >= pageCount - 1)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear {
            loadPDF()
        }
    }

    private func loadPDF() {
        let isSecure = book.fileURL.startAccessingSecurityScopedResource()
        defer {
            if isSecure {
                book.fileURL.stopAccessingSecurityScopedResource()
            }
        }

        if let document = PDFDocument(url: book.fileURL) {
            pdfDocument = document
            pageCount = document.pageCount
            currentPage = min(book.lastReadPage, pageCount - 1)
        }
    }

    private func previousPage() {
        if readingDirection == .rightToLeft {
            nextPage()
        } else {
            if currentPage > 0 {
                currentPage -= 1
                onPageChange(currentPage)
            }
        }
    }

    private func nextPage() {
        if readingDirection == .rightToLeft {
            if currentPage > 0 {
                currentPage -= 1
                onPageChange(currentPage)
            }
        } else {
            if currentPage < pageCount - 1 {
                currentPage += 1
                onPageChange(currentPage)
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    let readingDirection: ReadingDirection

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = readingDirection == .rightToLeft ? .horizontal : .vertical
        pdfView.usePageViewController(true, withViewOptions: nil)
        pdfView.backgroundColor = .black
        pdfView.maxScaleFactor = 5.0
        pdfView.minScaleFactor = 0.5

        // Set initial page
        if let page = document.page(at: currentPage) {
            pdfView.go(to: page)
        }

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // Update page if changed
        if let page = document.page(at: currentPage), uiView.currentPage != page {
            uiView.go(to: page)
        }

        // Apply scale and offset
        uiView.scaleFactor = scale
    }
}