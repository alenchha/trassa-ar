import SwiftUI
import RealityKit

/// Встраивает ARView контроллера в SwiftUI
struct ARViewContainer: UIViewRepresentable {
    let controller: ARSessionController

    func makeUIView(context: Context) -> ARView { controller.arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
