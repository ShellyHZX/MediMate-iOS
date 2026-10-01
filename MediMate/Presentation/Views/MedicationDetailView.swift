import SwiftUI

struct MedicationDetailView: View {
    @EnvironmentObject private var dependencies: MedicationManagementDependencies
    @Environment(\.dismiss) private var dismiss
    @State private var medication: Medication

    private let onMedicationChanged: () -> Void

    init(
        medication: Medication,
        onMedicationChanged: @escaping () -> Void = { }
    ) {
        _medication = State(initialValue: medication)
        self.onMedicationChanged = onMedicationChanged
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(medication.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(MedicationPresentationFormatter.dosage(medication.dosage))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("Schedule") {
                LabeledContent("Repeats", value: "Every day")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Dose times")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(MedicationPresentationFormatter.doseTimes(medication.schedule.dailyDoseTimes))
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 4)
            }

            if let instructions = medication.instructions, !instructions.isEmpty {
                Section("Instructions") {
                    Text(instructions)
                }
            }

            Section("Status") {
                Label(
                    medication.isActive ? "Active" : "Inactive",
                    systemImage: medication.isActive ? "checkmark.circle" : "pause.circle"
                )
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Medication")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit") {
                    MedicationFormView(
                        viewModel: MedicationFormViewModel(
                            mode: .edit(medication),
                            addMedicationUseCase: dependencies.addMedicationUseCase,
                            updateMedicationUseCase: dependencies.updateMedicationUseCase,
                            deactivateMedicationUseCase: dependencies.deactivateMedicationUseCase
                        )
                    ) { completion in
                        switch completion {
                        case .saved(let updatedMedication):
                            medication = updatedMedication
                            onMedicationChanged()

                        case .deactivated(let updatedMedication):
                            medication = updatedMedication
                            onMedicationChanged()
                            dismiss()
                        }
                    }
                }
                .accessibilityLabel("Edit Medication")
            }
        }
    }
}
