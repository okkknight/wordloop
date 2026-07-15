import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        VStack(spacing: 8) {
            Text("WordLoop")
                .font(.title.bold())

            Text("Native skeleton")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("wordloop.root.skeleton")
    }
}

#Preview {
    RootView(container: .preview)
}
