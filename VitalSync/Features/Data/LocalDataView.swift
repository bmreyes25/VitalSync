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
                            description: Text("Connect to Oura, then import recent heart rate on the Sync tab.")
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
                            GlassCard {
                                HStack(spacing: 16) {
                                    VitalIcon(symbol: "heart.fill", tint: VitalPalette.coral)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(metric.kindRawValue == HealthMetricKind.heartRate.rawValue ? "Heart rate" : metric.kindRawValue)
                                            .font(.headline)
                                        Text(metric.startDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let value = metric.value {
                                        Text("\(value, specifier: "%.0f") bpm")
                                            .font(.headline.monospacedDigit())
                                    }
                                }
                            }
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
