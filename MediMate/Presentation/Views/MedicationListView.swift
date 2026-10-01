import SwiftUI

struct MedicationListView: View {
    @ObservedObject var viewModel: MedicationListViewModel

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MedicationFormPlaceholderView(mode: .add)
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
        List {
            if let errorMessage = viewModel.errorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button("Retry") {
                            Task {
                                await viewModel.retry()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if !viewModel.activeMedications.isEmpty {
                Section("Active") {
                    ForEach(viewModel.activeMedications) { medication in
                        NavigationLink {
                            MedicationDetailView(medication: medication)
                        } label: {
                            MedicationRowView(medication: medication)
                        }
                    }
                }
            }

            if !viewModel.inactiveMedications.isEmpty {
                Section("Inactive") {
                    ForEach(viewModel.inactiveMedications) { medication in
                        NavigationLink {
                            MedicationDetailView(medication: medication)
                        } label: {
                            MedicationRowView(medication: medication)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 8)
                    .accessibilityLabel("Refreshing medications")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No medications yet", systemImage: "pills")
        } description: {
            Text("Add your medications to keep track of when each dose is due.")
        } actions: {
            NavigationLink("Add Medication") {
                MedicationFormPlaceholderView(mode: .add)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func errorState(message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to load medications", systemImage: "exclamationmark.circle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task {
                    await viewModel.retry()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct MedicationRowView: View {
    let medication: Medication

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(medication.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if !medication.isActive {
                    Text("Inactive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(MedicationPresentationFormatter.dosage(medication.dosage))
                .font(.subheadline)
                .foregroundStyle(.primary)

            Text(MedicationPresentationFormatter.doseTimes(medication.schedule.dailyDoseTimes))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let status = medication.isActive ? "Active" : "Inactive"
        let times = MedicationPresentationFormatter.doseTimes(medication.schedule.dailyDoseTimes)
        return "\(medication.name), \(MedicationPresentationFormatter.dosage(medication.dosage)), \(times), \(status)"
    }
}
