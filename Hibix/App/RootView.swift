import SwiftUI

struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        VStack(spacing: 16) {
            Text("Hibix")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("STEP1 基盤起動済み")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
