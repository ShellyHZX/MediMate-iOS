import SwiftUI

struct MedicationListView: View {
    @ObservedObject var viewModel: MedicationListViewModel
    @EnvironmentObject private var dependencies: MedicationManagementDependencies

    var body: some View {
        Group {
            if viewModel.medications.isEmpty, viewModel.isLoading {
                ProgressView("Loading medications")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.medications.isEmpty, let errorMessage = viewModel.errorMessage {
                errorState(message: errorMessage)
            } else if viewModel.medications.isEmpty {
                emptyState
            } else {
                medicationList
            }
        }
        .navigationTitle("Medications")
        .background(MediMateTheme.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    addMedicationForm
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Medication")
            }
        }
        .task {
            await viewModel.loadMedications()
        }
        .refreshable {
            await viewModel.loadMedications()
        }
    }

    private var medicationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
            if let errorMessage = viewModel.errorMessage {
                    MediMateSurface(style: .flat) {
                        VStack(alignment: .leading, spacing: 10) {
                        Text(errorMessage)
                            .font(.subheadline)
                                .foregroundStyle(MediMateTheme.secondaryText)

                        Button("Retry") {
                            Task {
                                await viewModel.retry()
                            }
                        }
                    }
                }
            }

            if !viewModel.activeMedications.isEmpty {
                    MedicationLibrarySection(title: "Active") {
                    ForEach(viewModel.activeMedications) { medication in
                        NavigationLink {
                            MedicationDetailView(medication: medication) {
                                Task {
                                    await viewModel.loadMedications()
                                }
                            }
                        } label: {
                            MedicationRowView(medication: medication)
                        }
                            .buttonStyle(.plain)
                    }
                }
            }

            if !viewModel.inactiveMedications.isEmpty {
                    MedicationLibrarySection(title: "Inactive") {
                    ForEach(viewModel.inactiveMedications) { medication in
                        NavigationLink {
                            MedicationDetailView(medication: medication) {
                                Task {
                                    await viewModel.loadMedications()
                                }
                            }
                        } label: {
                            MedicationRowView(medication: medication)
                        }
                            .buttonStyle(.plain)
                    }
                }
            }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(MediMateTheme.background)
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 8)
                    .accessibilityLabel("Refreshing medications")
            }
        }
    }

    private var emptyState: some View {
        MediMateEmptyState(
            title: "No medications yet",
            message: "Add a medication to start your routine.",
            systemImage: "pills",
            actionTitle: "Add Medication",
            action: nil
        )
        .overlay(alignment: .bottom) {
            NavigationLink {
                addMedicationForm
            } label: {
                Text("Add Medication")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(MediMateTheme.accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
    }

    private func errorState(message: String) -> some View {
        MediMateEmptyState(
            title: "Unable to load medications",
            message: message,
            systemImage: "exclamationmark.circle",
            actionTitle: "Retry",
            action: {
                Task {
                    await viewModel.retry()
                }
            }
        )
    }

    private var addMedicationForm: some View {
        MedicationFormView(
            viewModel: MedicationFormViewModel(
                mode: .add,
                addMedicationAndScheduleUseCase: dependencies.addMedicationAndScheduleUseCase,
                updateMedicationAndRescheduleUseCase: dependencies.updateMedicationAndRescheduleUseCase,
                deactivateMedicationUseCase: dependencies.deactivateMedicationUseCase,
                deleteMedicationUseCase: dependencies.deleteMedicationUseCase,
                widgetSnapshotSynchronizer: dependencies.widgetSnapshotSynchronizer,
                notificationScheduler: dependencies.notificationScheduler
            )
        ) { _ in
            Task {
                await viewModel.loadMedications()
            }
        }
    }
}

private struct MedicationLibrarySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(MediMateTheme.primaryText)
                .accessibilityAddTraits(.isHeader)

            MediMateSurface(style: .standard) {
                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
}

private struct MedicationRowView: View {
    let medication: Medication

    var body: some View {
        HStack(spacing: 14) {
            MedicationGlyph(seed: medication.name, isActive: medication.isActive)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(medication.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(medication.isActive ? MediMateTheme.primaryText : MediMateTheme.secondaryText)

                    if !medication.isActive {
                        Text("Inactive")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MediMateTheme.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }

                Text(MedicationPresentationFormatter.dosage(medication.dosage))
                    .font(.body.weight(.medium))
                    .foregroundStyle(medication.isActive ? MediMateTheme.primaryText : MediMateTheme.secondaryText)

                Text(MedicationPresentationFormatter.doseTimes(medication.schedule.dailyDoseTimes))
                    .font(.subheadline)
                    .foregroundStyle(MediMateTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MediMateTheme.secondaryText)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let status = medication.isActive ? "Active" : "Inactive"
        let times = MedicationPresentationFormatter.doseTimes(medication.schedule.dailyDoseTimes)
        return "\(medication.name), \(MedicationPresentationFormatter.dosage(medication.dosage)), \(times), \(status)"
    }
}
