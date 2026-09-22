import SwiftUI

struct PrivacyShield<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            protectedContent

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

    @ViewBuilder
    private var protectedContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SyntheticStoreScreenshots") {
            content
        } else {
            content.privacySensitive()
        }
        #else
        content.privacySensitive()
        #endif
    }
}
