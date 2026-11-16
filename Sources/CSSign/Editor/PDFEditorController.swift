import Combine
import PDFKit
import UIKit

/// Owns the PDFView and handles placing, moving (pan), resizing (pinch),
/// selecting (tap) and flattening stamps.
final class PDFEditorController: NSObject, ObservableObject, UIGestureRecognizerDelegate {
    let pdfView = PDFView()

    @Published private(set) var selected: StampAnnotation?
    @Published private(set) var hasChanges = false

    private var panTarget: StampAnnotation?
    private var pinchTarget: StampAnnotation?
    private var lastPanPoint: CGPoint = .zero
    private var pinchStartSize: CGSize = .zero

    override init() {
        super.init()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .secondarySystemBackground

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        for recognizer in [pan, pinch, tap] as [UIGestureRecognizer] {
            recognizer.delegate = self
            pdfView.addGestureRecognizer(recognizer)
        }
    }

    func load(_ url: URL) {
        pdfView.document = PDFDocument(url: url)
    }

    // MARK: Adding

    func addImage(_ image: UIImage) {
        let width: CGFloat = 160
        let height = width * image.size.height / max(image.size.width, 1)
        insert(StampAnnotation(content: .image(image), bounds: CGRect(x: 0, y: 0, width: width, height: height)))
    }

    func addText(_ text: String, fontSize: CGFloat = 14) {
        let font = UIFont.systemFont(ofSize: fontSize)
        let width = ceil((text as NSString).size(withAttributes: [.font: font]).width) + 2
        let height = fontSize * StampAnnotation.lineHeightRatio
        insert(StampAnnotation(content: .text(text), bounds: CGRect(x: 0, y: 0, width: width, height: height)))
    }

    /// Drops the stamp in the middle of the visible part of the current page.
    private func insert(_ stamp: StampAnnotation) {
        guard let page = pdfView.currentPage else { return }
        let pageBox = page.bounds(for: pdfView.displayBox)
        var visible = pdfView.convert(pdfView.bounds, to: page).intersection(pageBox)
        if visible.isNull || visible.isEmpty { visible = pageBox }
        stamp.bounds.origin = CGPoint(
            x: visible.midX - stamp.bounds.width / 2,
            y: visible.midY - stamp.bounds.height / 2
        )
        page.addAnnotation(stamp)
        select(stamp)
        hasChanges = true
    }

    // MARK: Selection

    func deleteSelected() {
        guard let stamp = selected, let page = stamp.page else { return }
        select(nil)
        page.removeAnnotation(stamp)
        pdfView.annotationsChanged(on: page)
        hasChanges = true
    }

    func markSaved() { hasChanges = false }

    private func select(_ stamp: StampAnnotation?) {
        if let old = selected {
            old.showsSelection = false
            redraw(old)
        }
        selected = stamp
        if let stamp {
            stamp.showsSelection = true
            redraw(stamp)
        }
    }

    private func redraw(_ annotation: PDFAnnotation) {
        if let page = annotation.page { pdfView.annotationsChanged(on: page) }
    }

    /// Topmost stamp under a point, with a finger-friendly margin.
    private func stamp(at location: CGPoint) -> StampAnnotation? {
        guard let page = pdfView.page(for: location, nearest: false) else { return nil }
        let point = pdfView.convert(location, to: page)
        return page.annotations.reversed()
            .compactMap { $0 as? StampAnnotation }
            .first { $0.bounds.insetBy(dx: -12, dy: -12).contains(point) }
    }

    // MARK: Gestures

    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        if recognizer is UITapGestureRecognizer { return true }
        // Only claim pans/pinches that start on a stamp; otherwise fail fast so
        // PDFView's own scrolling and zooming take over.
        guard let hit = stamp(at: recognizer.location(in: pdfView)) else { return false }
        if recognizer is UIPinchGestureRecognizer { pinchTarget = hit } else { panTarget = hit }
        return true
    }

    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        // Taps never block PDFView; our pan and pinch can run together.
        recognizer is UITapGestureRecognizer || other.delegate === self
    }

    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
        // The scroll view waits for our pan/pinch to fail, so dragging a stamp doesn't scroll.
        !(recognizer is UITapGestureRecognizer) && other.view is UIScrollView
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        select(stamp(at: recognizer.location(in: pdfView)))
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let stamp = panTarget, let page = stamp.page else { return }
        let point = pdfView.convert(recognizer.location(in: pdfView), to: page)
        switch recognizer.state {
        case .began:
            select(stamp)
            lastPanPoint = point
        case .changed:
            stamp.bounds = stamp.bounds.offsetBy(dx: point.x - lastPanPoint.x, dy: point.y - lastPanPoint.y)
            lastPanPoint = point
            redraw(stamp)
            hasChanges = true
        default:
            panTarget = nil
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let stamp = pinchTarget else { return }
        switch recognizer.state {
        case .began:
            select(stamp)
            pinchStartSize = stamp.bounds.size
        case .changed:
            let width = max(pinchStartSize.width * recognizer.scale, 12)
            let height = width * pinchStartSize.height / max(pinchStartSize.width, 1)
            let center = CGPoint(x: stamp.bounds.midX, y: stamp.bounds.midY)
            stamp.bounds = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
            redraw(stamp)
            hasChanges = true
        default:
            pinchTarget = nil
        }
    }

    // MARK: Export

    /// Redraws every page (with its annotations) into a fresh PDF, so stamps
    /// become part of the page content and can't be moved or removed later.
    func flattenedPDF() -> Data? {
        guard let document = pdfView.document else { return nil }
        select(nil)

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { return nil }

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let box = page.bounds(for: .cropBox)
            let quarterTurn = abs(page.rotation) % 180 == 90
            var mediaBox = CGRect(
                origin: .zero,
                size: quarterTurn ? CGSize(width: box.height, height: box.width) : box.size
            )
            context.beginPage(mediaBox: &mediaBox)
            context.saveGState()
            page.transform(context, for: .cropBox) // handles crop origin and rotation
            page.draw(with: .cropBox, to: context)
            context.restoreGState()
            context.endPage()
        }
        context.closePDF()
        return data as Data
    }
}
