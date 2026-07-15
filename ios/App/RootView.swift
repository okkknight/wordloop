import SwiftUI
import WordLoopFeatures

struct RootView: View {
    let container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        DesignSystemGalleryView()
            .environment(\.dynamicTypeSize, fixtureAccessibilityText ? .accessibility3 : dynamicTypeSize)
    }

    private var fixtureAccessibilityText: Bool {
        ProcessInfo.processInfo.arguments.contains("-wordloop-fixture-accessibility-text")
    }
}

#Preview {
    RootView(container: .preview)
}
