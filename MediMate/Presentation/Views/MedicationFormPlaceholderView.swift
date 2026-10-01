import SwiftUI

struct MedicationFormPlaceholderView: View {
    enum Mode {
        case add
        case edit(Medication)
    }

    let mode: Mode

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "square.and.pencil")
        } description: {
            Text("The medication form will be added in the next milestone.")
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        switch mode {
        case .add:
            return "Add Medication"
        case .edit:
            return "Edit Medication"
        }
    }
}
