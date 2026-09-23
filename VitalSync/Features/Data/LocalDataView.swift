import SwiftUI
import SwiftData

struct LocalDataView: View {
    @Query(sort: \StoredMetric.startDate, order: .reverse) private var metrics: [StoredMetric]

    var body: some View {
        ZStack {
            VitalBackground()

            ScrollView {
                if metrics.isEmpty {
                    GlassCard {
                        ContentUnavailableView(
                            "No imported data",
                            systemImage: "waveform.path.ecg",
                            description: Text("Connect to Oura, update permissions, then import recent measurements on the Sync tab.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 340)
                    }
                    .padding(18)
                } else {
                    LazyVStack(spacing: 10) {
                        Text("\(metrics.count) saved measurements")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(metrics) { metric in
                            NavigationLink {
                                MetricDetailView(metric: metric)
                            } label: {
                                GlassCard {
                                    HStack(spacing: 16) {
                                        VitalIcon(symbol: metric.presentation.symbol, tint: VitalPalette.coral)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(metric.presentation.title)
                                                .font(.headline)
                                            Text(metric.presentation.dateLabel(for: metric))
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if let value = metric.value {
                                            Text(metric.presentation.valueLabel(value))
                                                .font(.headline.monospacedDigit())
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                }
            }
        }
        .navigationTitle("Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MetricDetailView: View {
    let metric: StoredMetric

    var body: some View {
        ZStack {
            VitalBackground()
            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Label("Source details", systemImage: "checkmark.shield.fill")
                            .font(.headline)
                            .foregroundStyle(VitalPalette.accent)
                        LabeledContent("Origin", value: metric.presentation.title + " · Oura")
                        LabeledContent("Recorded", value: metric.presentation.dateLabel(for: metric))
                        if let value = metric.value {
                            LabeledContent("Measurement", value: metric.presentation.valueLabel(value))
                        }
                        LabeledContent("On this iPhone", value: "Saved")
                        LabeledContent("VitalSync export", value: "Local only")
                        Text(metric.presentation.explanation)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Measurement")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MetricPresentation {
    let title: String
    let symbol: String
    let suffix: String
    let explanation: String
    let isSigned: Bool

    private init(title: String, symbol: String, suffix: String, explanation: String, isSigned: Bool) {
        self.title = title
        self.symbol = symbol
        self.suffix = suffix
        self.explanation = explanation
        self.isSigned = isSigned
    }

    init(kind: HealthMetricKind?) {
        switch kind {
        case .heartRate:
            self = Self(title: "Heart rate", symbol: "heart.fill", suffix: "bpm",
                        explanation: "Oura already offers heart-rate export to Apple Health, so VitalSync keeps this import local.", isSigned: false)
        case .oxygenSaturation:
            self = Self(title: "Sleep SpO₂ average", symbol: "lungs.fill", suffix: "%",
                        explanation: "This is Oura's average oxygen saturation during sleep, labeled by sleep day. The API does not provide the exact measurement interval, so VitalSync keeps it local.", isSigned: false)
        case .rmssd:
            self = Self(title: "Sleep HRV (RMSSD)", symbol: "waveform.path.ecg", suffix: "ms",
                        explanation: "This is Oura's average sleep HRV, measured as RMSSD. Apple Health's HRV type is SDNN, a different calculation, so VitalSync never writes this value as SDNN.", isSigned: false)
        case .bodyTemperatureDeviation:
            self = Self(title: "Sleep temperature change", symbol: "thermometer.medium", suffix: "°C from baseline",
                        explanation: "This is Oura's temperature deviation from your personal baseline during sleep. It is not an absolute body temperature, so VitalSync keeps it local.", isSigned: true)
        default:
            self = Self(title: "Oura measurement", symbol: "waveform.path", suffix: "", explanation: "Saved locally from Oura.", isSigned: false)
        }
    }

    func valueLabel(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...1)))
        return "\(isSigned && value > 0 ? "+" : "")\(number) \(suffix)"
    }

    func dateLabel(for metric: StoredMetric) -> String {
        let attributes = (try? JSONDecoder().decode([String: String].self, from: metric.encodedAttributes)) ?? [:]
        if attributes["precision"] == "day", let day = attributes["day"] {
            return "Sleep day \(day)"
        }
        if metric.endDate > metric.startDate {
            return "\(metric.startDate.formatted(date: .abbreviated, time: .shortened)) – \(metric.endDate.formatted(date: .omitted, time: .shortened))"
        }
        return metric.startDate.formatted(date: .abbreviated, time: .shortened)
    }
}

private extension StoredMetric {
    var presentation: MetricPresentation {
        MetricPresentation(kind: HealthMetricKind(rawValue: kindRawValue))
    }
}
