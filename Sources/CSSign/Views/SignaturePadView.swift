import PencilKit
import SwiftUI

struct SignaturePadView: View {
    var onSave: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var canvas = PKCanvasView()
    @State private var isEmpty = true
    @State private var ink: Ink = .black

    enum Ink: String, CaseIterable, Identifiable {
        case black, blue
        var id: Self { self }
        var color: UIColor {
            switch self {
            case .black: UIColor(white: 0.05, alpha: 1)
            case .blue: UIColor(red: 0.05, green: 0.2, blue: 0.6, alpha: 1)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                SignatureCanvas(canvas: canvas, ink: ink.color, isEmpty: $isEmpty)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .bottom) {
                        // Signing line, purely visual.
                        Rectangle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 60)
                            .allowsHitTesting(false)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))

                Picker("Ink", selection: $ink) {
                    ForEach(Ink.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                Text("Sign with your finger or Apple Pencil")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("New Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear") { canvas.drawing = PKDrawing() }.disabled(isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(!isEmpty)
    }

    private func save() {
        let drawing = canvas.drawing
        var image: UIImage?
        // Render in light mode so PencilKit doesn't invert dark ink to white.
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: drawing.bounds.insetBy(dx: -8, dy: -8), scale: 3)
        }
        if let image { onSave(image) }
        dismiss()
    }
}

private struct SignatureCanvas: UIViewRepresentable {
    let canvas: PKCanvasView
    let ink: UIColor
    @Binding var isEmpty: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.overrideUserInterfaceStyle = .light
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.tool = PKInkingTool(.pen, color: ink, width: 4)
    }

    func makeCoordinator() -> Coordinator { Coordinator(isEmpty: $isEmpty) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var isEmpty: Binding<Bool>
        init(isEmpty: Binding<Bool>) { self.isEmpty = isEmpty }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            isEmpty.wrappedValue = canvasView.drawing.strokes.isEmpty
        }
    }
}
