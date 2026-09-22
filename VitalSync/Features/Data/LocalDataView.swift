import SwiftUI

struct LocalDataView: View {
    var body: some View {
        ContentUnavailableView(
            "No imported data",
            systemImage: "waveform.path.ecg",
            description: Text("Authorized Oura records will appear here after a successful sync.")
        )
        .navigationTitle("Data")
    }
}
