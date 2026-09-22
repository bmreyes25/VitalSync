import SwiftUI

enum VitalPalette {
    static let accent = Color(red: 0.08, green: 0.68, blue: 0.72)
    static let deepBlue = Color(red: 0.03, green: 0.18, blue: 0.38)
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.36)
    static let success = Color(red: 0.20, green: 0.76, blue: 0.52)
}

struct VitalBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(colorScheme == .dark ? .black : .systemGroupedBackground)

            RadialGradient(
                colors: [VitalPalette.accent.opacity(colorScheme == .dark ? 0.32 : 0.22), .clear],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 430
            )

            RadialGradient(
                colors: [VitalPalette.deepBlue.opacity(colorScheme == .dark ? 0.58 : 0.12), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .glassEffect(.regular.tint(VitalPalette.accent.opacity(0.08)), in: .rect(cornerRadius: 26))
    }
}

struct VitalIcon: View {
    let symbol: String
    var tint: Color = VitalPalette.accent

    var body: some View {
        Image(systemName: symbol)
            .font(.title2.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 50, height: 50)
            .glassEffect(.regular.tint(tint.opacity(0.14)), in: .circle)
            .accessibilityHidden(true)
    }
}

struct StatusPill: View {
    let title: String
    let isPositive: Bool

    var body: some View {
        Label(title, systemImage: isPositive ? "checkmark.circle.fill" : "circle.dashed")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isPositive ? VitalPalette.success : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
    }
}
