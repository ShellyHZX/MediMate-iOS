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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                overview

                DetailSection(title: "Schedule", systemImage: "clock") {
                    DetailRow(title: "Repeats", value: "Every day")
                    DetailRow(
                        title: "Dose times",
                        value: MedicationPresentationFormatter.doseTimes(medication.schedule.dailyDoseTimes)
                    )
                }

            if let instructions = medication.instructions, !instructions.isEmpty {
                    DetailSection(title: "Instructions", systemImage: "text.alignleft") {
                        Text(instructions)
                            .font(.body)
                            .foregroundStyle(MediMateTheme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                DetailSection(title: "Status", systemImage: medication.isActive ? "checkmark.circle" : "pause.circle") {
                    Label(
                        medication.isActive ? "Active" : "Inactive",
                        systemImage: medication.isActive ? "checkmark.circle.fill" : "pause.circle.fill"
                    )
                    .font(.body.weight(.medium))
                    .foregroundStyle(medication.isActive ? MediMateTheme.accent : MediMateTheme.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(MediMateTheme.background)
        .navigationTitle("Medication")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit") {
                    MedicationFormView(
                        viewModel: MedicationFormViewModel(
                            mode: .edit(medication),
                            addMedicationAndScheduleUseCase: dependencies.addMedicationAndScheduleUseCase,
                            updateMedicationAndRescheduleUseCase: dependencies.updateMedicationAndRescheduleUseCase,
                            deactivateMedicationUseCase: dependencies.deactivateMedicationUseCase,
                            deleteMedicationUseCase: dependencies.deleteMedicationUseCase,
                            widgetSnapshotSynchronizer: dependencies.widgetSnapshotSynchronizer,
                            notificationScheduler: dependencies.notificationScheduler
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

                        case .deleted:
                            onMedicationChanged()
                            dismiss()
                        }
                    }
                }
                .accessibilityLabel("Edit Medication")
            }
        }
    }

    private var overview: some View {
        MediMateSurface(style: .highlighted) {
            HStack(alignment: .top, spacing: 16) {
                MedicationGlyph(seed: medication.name, isActive: medication.isActive)

                VStack(alignment: .leading, spacing: 8) {
                    Text(medication.name)
                        .font(.title.weight(.bold))
                        .foregroundStyle(MediMateTheme.primaryText)

                    Text(MedicationPresentationFormatter.dosage(medication.dosage))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(MediMateTheme.secondaryText)

                    Text(medication.isActive ? "Active" : "Inactive")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(medication.isActive ? MediMateTheme.accent : MediMateTheme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            medication.isActive ? MediMateTheme.accent.opacity(0.12) : Color.secondary.opacity(0.12),
                            in: Capsule()
                        )
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(MediMateTheme.primaryText)
                .accessibilityAddTraits(.isHeader)

            MediMateSurface(style: .standard) {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
            }
        }
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MediMateTheme.secondaryText)

            Text(value)
                .font(.body.weight(.medium))
                .foregroundStyle(MediMateTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
