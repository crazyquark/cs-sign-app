import UIKit

/// App Store screenshot mode, used only by `scripts/screenshots.sh` in CI.
///
/// Launching with `-PSScreenshot <screen>` (library, editor or signatures)
/// fills the app with demo content and opens that screen. Launch arguments of
/// the form `-key value` land in UserDefaults, so no extra parsing is needed.
/// Without the argument this does nothing.
enum ScreenshotMode {
    enum Screen: String {
        case library, editor, signatures
    }

    static let screen: Screen? = UserDefaults.standard.string(forKey: "PSScreenshot").flatMap(Screen.init)
    static var isActive: Bool { screen != nil }

    static let documentName = "Apartment Lease Agreement"

    /// Where the demo signature goes on the demo document (PDF page coordinates).
    static let signatureCenter = CGPoint(x: 190, y: 196)
    static let dateCenter = CGPoint(x: 444, y: 182)

    /// Writes the demo documents and signatures. Call before the stores load.
    static func seedIfNeeded() {
        guard isActive else { return }
        let fm = FileManager.default

        let documents = URL.documentsDirectory
        for name in [documentName, "Invoice 2026-114", "Consent Form"] {
            let url = documents.appending(path: "\(name).pdf")
            if !fm.fileExists(atPath: url.path) {
                try? demoPDF(title: name).write(to: url)
            }
        }

        let signatures = URL.applicationSupportDirectory.appending(path: "Signatures", directoryHint: .isDirectory)
        try? fm.createDirectory(at: signatures, withIntermediateDirectories: true)
        let files: [(String, UIImage)] = [
            ("20260101-000000-demo1.png", signatureImage(ink: UIColor(red: 0.05, green: 0.2, blue: 0.6, alpha: 1))),
            ("20260101-000001-demo2.png", initialsImage()),
        ]
        for (name, image) in files {
            let url = signatures.appending(path: name)
            if !fm.fileExists(atPath: url.path), let data = image.pngData() {
                try? data.write(to: url)
            }
        }
    }

    static var documentURL: URL {
        URL.documentsDirectory.appending(path: "\(documentName).pdf")
    }

    // MARK: Demo content

    private static func demoPDF(title: String) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            context.beginPage()
            let titleFont = UIFont.systemFont(ofSize: 22, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 11)
            let labelFont = UIFont.systemFont(ofSize: 9)
            let gray = UIColor(white: 0.35, alpha: 1)

            (title as NSString).draw(at: CGPoint(x: 72, y: 72), withAttributes: [.font: titleFont])

            let body = """
            This agreement is made between the Landlord and the Tenant for the rental of the \
            residential property described below. The term begins on the first day of the month \
            and continues for twelve (12) months.

            1. Rent. The Tenant agrees to pay the monthly rent in advance on or before the first \
            day of each month.

            2. Deposit. A security deposit equal to one month's rent is due at signing and will be \
            returned within thirty (30) days after the end of the term, less any lawful deductions.

            3. Maintenance. The Tenant shall keep the property clean and in good condition and \
            promptly report any damage or needed repairs to the Landlord.

            4. Entire agreement. This document is the entire agreement between the parties and may \
            only be changed in writing, signed by both parties.
            """
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 3
            (body as NSString).draw(
                in: CGRect(x: 72, y: 120, width: 468, height: 420),
                withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black, .paragraphStyle: paragraph]
            )

            // Signature and date lines (UIKit coordinates: y grows downward).
            let lineY: CGFloat = 792 - 170
            context.cgContext.setStrokeColor(gray.cgColor)
            context.cgContext.setLineWidth(0.75)
            context.cgContext.strokeLineSegments(between: [
                CGPoint(x: 72, y: lineY), CGPoint(x: 312, y: lineY),
                CGPoint(x: 384, y: lineY), CGPoint(x: 540, y: lineY),
            ])
            ("Tenant signature" as NSString).draw(at: CGPoint(x: 72, y: lineY + 6), withAttributes: [.font: labelFont, .foregroundColor: gray])
            ("Date" as NSString).draw(at: CGPoint(x: 384, y: lineY + 6), withAttributes: [.font: labelFont, .foregroundColor: gray])
        }
    }

    /// A handwritten-looking signature drawn with Bézier curves.
    static func signatureImage(ink: UIColor) -> UIImage {
        let size = CGSize(width: 600, height: 240)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 40, y: 170))
            path.addCurve(to: CGPoint(x: 150, y: 70), controlPoint1: CGPoint(x: 60, y: 60), controlPoint2: CGPoint(x: 130, y: 30))
            path.addCurve(to: CGPoint(x: 95, y: 190), controlPoint1: CGPoint(x: 170, y: 120), controlPoint2: CGPoint(x: 120, y: 200))
            path.addCurve(to: CGPoint(x: 200, y: 130), controlPoint1: CGPoint(x: 70, y: 175), controlPoint2: CGPoint(x: 150, y: 100))
            path.addCurve(to: CGPoint(x: 260, y: 160), controlPoint1: CGPoint(x: 220, y: 150), controlPoint2: CGPoint(x: 240, y: 175))
            path.addCurve(to: CGPoint(x: 320, y: 110), controlPoint1: CGPoint(x: 280, y: 145), controlPoint2: CGPoint(x: 295, y: 105))
            path.addCurve(to: CGPoint(x: 360, y: 165), controlPoint1: CGPoint(x: 345, y: 115), controlPoint2: CGPoint(x: 335, y: 170))
            path.addCurve(to: CGPoint(x: 430, y: 105), controlPoint1: CGPoint(x: 385, y: 160), controlPoint2: CGPoint(x: 400, y: 100))
            path.addCurve(to: CGPoint(x: 480, y: 160), controlPoint1: CGPoint(x: 460, y: 110), controlPoint2: CGPoint(x: 455, y: 165))
            path.addCurve(to: CGPoint(x: 565, y: 120), controlPoint1: CGPoint(x: 505, y: 155), controlPoint2: CGPoint(x: 535, y: 125))
            // Underline flourish.
            path.move(to: CGPoint(x: 120, y: 205))
            path.addCurve(to: CGPoint(x: 520, y: 195), controlPoint1: CGPoint(x: 250, y: 220), controlPoint2: CGPoint(x: 400, y: 185))
            ink.setStroke()
            path.lineWidth = 9
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }

    /// Initials, for a second signature in the library.
    private static func initialsImage() -> UIImage {
        let size = CGSize(width: 360, height: 240)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 60, y: 60))
            path.addCurve(to: CGPoint(x: 70, y: 190), controlPoint1: CGPoint(x: 80, y: 110), controlPoint2: CGPoint(x: 95, y: 170))
            path.addCurve(to: CGPoint(x: 30, y: 160), controlPoint1: CGPoint(x: 55, y: 205), controlPoint2: CGPoint(x: 30, y: 190))
            path.move(to: CGPoint(x: 150, y: 190))
            path.addCurve(to: CGPoint(x: 210, y: 50), controlPoint1: CGPoint(x: 170, y: 130), controlPoint2: CGPoint(x: 195, y: 60))
            path.addCurve(to: CGPoint(x: 270, y: 190), controlPoint1: CGPoint(x: 225, y: 60), controlPoint2: CGPoint(x: 250, y: 130))
            path.move(to: CGPoint(x: 170, y: 140))
            path.addCurve(to: CGPoint(x: 330, y: 120), controlPoint1: CGPoint(x: 220, y: 130), controlPoint2: CGPoint(x: 280, y: 125))
            UIColor(white: 0.08, alpha: 1).setStroke()
            path.lineWidth = 8
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }
}
