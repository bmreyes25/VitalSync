import SwiftUI

struct PrivacyShield<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            content
                .privacySensitive()

            if scenePhase != .active {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "heart.text.clipboard.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.blue)
                            Text("VitalSync")
                                .font(.headline)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("VitalSync content hidden for privacy")
                    }
                    .transition(.opacity)
            }
        }
    }
}
