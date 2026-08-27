import SwiftUI

@main
@MainActor
struct BlackHoleEffectDemoApp: App {
    @State private var captureService = DemoScreenCaptureService()

    var body: some Scene {
        WindowGroup("BlackHoleKit Desktop Effect") {
            BlackHoleEffectView(captureService: captureService)
        }
        .defaultSize(width: 620, height: 620)
    }
}
