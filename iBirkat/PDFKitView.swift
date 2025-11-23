import SwiftUI
import PDFKit
import UIKit

struct PDFKitView: UIViewRepresentable {
    let pdfName: String
    @Binding var currentPageIndex: Int

    // MARK: - Coordinator

    class Coordinator: NSObject, PDFViewDelegate {
        var currentPageIndex: Binding<Int>

        init(currentPageIndex: Binding<Int>) {
            self.currentPageIndex = currentPageIndex
        }

        func pdfViewPageChanged(_ notification: Notification) {
            guard
                let pdfView = notification.object as? PDFView,
                let document = pdfView.document,
                let page = pdfView.currentPage
            else { return }

            let index = document.index(for: page)
            if currentPageIndex.wrappedValue != index {
                currentPageIndex.wrappedValue = index

                // лёгкий хаптик при смене страницы
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(currentPageIndex: $currentPageIndex)
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.delegate = context.coordinator

        // Одна страница, перелистывание свайпом
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true, withViewOptions: [
            UIPageViewController.OptionsKey.interPageSpacing: 8
        ])

        // Книга справа-налево
        pdfView.semanticContentAttribute = .forceRightToLeft

        // Без теней/разрывов
        if #available(iOS 12.0, *) {
            pdfView.pageShadowsEnabled = false
        }
        pdfView.displaysPageBreaks = false
        pdfView.pageBreakMargins = .zero

        pdfView.backgroundColor = .white
        pdfView.displayBox = .cropBox

        // Автоподбор масштаба, чтобы страница влезала целиком
        pdfView.autoScales = true

        // Загружаем документ
        loadDocument(in: pdfView)

        // После первой загрузки зафиксируем масштаб
        DispatchQueue.main.async {
            let fixed = pdfView.scaleFactor
            pdfView.minScaleFactor = fixed
            pdfView.maxScaleFactor = fixed
        }

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Если сменился pdfName — подменяем документ
        loadDocument(in: pdfView)

        guard let document = pdfView.document else { return }

        let maxIndex = max(document.pageCount - 1, 0)
        let clampedIndex = clamp(currentPageIndex, max: maxIndex)

        if let page = document.page(at: clampedIndex),
           pdfView.currentPage != page {
            pdfView.go(to: page)
        }

        // Дать PDFView подобрать масштаб как раньше
        pdfView.autoScales = true
        pdfView.displayBox = .cropBox

        // И снова зафиксировать текущий масштаб (запретить зум)
        DispatchQueue.main.async {
            let fixed = pdfView.scaleFactor
            pdfView.minScaleFactor = fixed
            pdfView.maxScaleFactor = fixed
        }
    }

    // MARK: - Helpers

    private func loadDocument(in pdfView: PDFView) {
        guard let url = Bundle.main.url(forResource: pdfName, withExtension: "pdf")
        else {
            pdfView.document = nil
            return
        }

        // Если уже загружен этот же документ — ничего не делаем
        if let currentDoc = pdfView.document,
           let currentURL = currentDoc.documentURL,
           currentURL == url {
            return
        }

        if let document = PDFDocument(url: url) {
            pdfView.document = document

            let maxIndex = max(document.pageCount - 1, 0)
            let startIndex = clamp(currentPageIndex, max: maxIndex)

            if let page = document.page(at: startIndex) {
                pdfView.go(to: page)
            }

            // Первый автоподбор масштаба
            pdfView.autoScales = true
        } else {
            pdfView.document = nil
        }
    }
}

// Ограничиваем индекс 0...max
private func clamp(_ index: Int, max: Int) -> Int {
    guard max >= 0 else { return 0 }
    return Swift.min(Swift.max(index, 0), max)
}
