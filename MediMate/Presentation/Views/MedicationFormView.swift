import SwiftUI

struct MedicationFormView: View {
    enum Completion {
        case saved(Medication)
        case deactivated(Medication)
    }

    @StateObject private var viewModel: MedicationFormViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDeactivationConfirmation = false
    @State private var isShowingError = false

    private let onCompletion: (Completion) -> Void

    init(
        viewModel: MedicationFormViewModel,
        onCompletion: @escaping (Completion) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCompletion = onCompletion
    }

    var body: some View {
        Form {
            medicationSection
            dosageSection
            scheduleSection
            instructionsSection

            if viewModel.isDeactivationAvailable {
                deactivationSection
            }
        }
        .navigationTitle(viewModel.isAddMode ? "Add Medication" : "Edit Medication")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task {
                        await save()
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: 12)
        }
        .alert("Unable to Save", isPresented: $isShowingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Please check the form and try again.")
        }
        .confirmationDialog(
            "Stop tracking this medication?",
            isPresented: $isShowingDeactivationConfirmation,
            titleVisibility: .visible
        ) {
            Button("Deactivate Medication", role: .destructive) {
                Task {
                    await deactivate()
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Existing dose history will be kept.")
        }
        .overlay {
            if viewModel.isSaving {
                ProgressView()
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Saving medication")
            }
        }
    }

    private var medicationSection: some View {
        Section("Medication") {
            TextField("Name", text: $viewModel.name)
                .textContentType(.name)
        }
    }

    private var dosageSection: some View {
        Section("Dosage") {
            TextField("Amount", text: $viewModel.dosageAmountText)
                .keyboardType(.decimalPad)

            Picker("Unit", selection: $viewModel.dosageUnit) {
                ForEach(DosageUnit.allCases, id: \.self) { unit in
                    Text(unit.rawValue)
                        .tag(unit)
                }
            }
        }
    }

    private var scheduleSection: some View {
        Section {
            LabeledContent("Repeats", value: "Every day")

            if viewModel.dailyDoseTimes.isEmpty {
                Text("Add at least one dose time.")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Add at least one dose time")
            } else {
                ForEach(viewModel.dailyDoseTimes.indices, id: \.self) { index in
                    doseTimeRow(index: index)
                }
                .onDelete { offsets in
                    for index in offsets.sorted(by: >) {
                        viewModel.removeDoseTime(at: index)
                    }
                }
            }

            Button {
                addDefaultDoseTime()
            } label: {
                Label("Add Time", systemImage: "plus")
            }
            .accessibilityLabel("Add dose time")
        } header: {
            Text("Schedule")
        }
    }

    private var instructionsSection: some View {
        Section("Instructions") {
            TextField("Optional instructions", text: $viewModel.instructions, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private var deactivationSection: some View {
        Section {
            Button(role: .destructive) {
                isShowingDeactivationConfirmation = true
            } label: {
                Text("Deactivate Medication")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.isSaving)
            .accessibilityLabel("Deactivate Medication")
        }
    }

    private func doseTimeRow(index: Int) -> some View {
        DatePicker(
            "Dose Time",
            selection: doseTimeBinding(for: index),
            displayedComponents: .hourAndMinute
        )
        .accessibilityLabel("Dose time \(index + 1)")
        .swipeActions {
            Button(role: .destructive) {
                viewModel.removeDoseTime(at: index)
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .accessibilityLabel("Remove dose time \(index + 1)")
        }
    }

    private func doseTimeBinding(for index: Int) -> Binding<Date> {
        Binding {
            guard viewModel.dailyDoseTimes.indices.contains(index) else {
                return MedicationDoseTimeDateBridge.defaultDate
            }

            return MedicationDoseTimeDateBridge.date(from: viewModel.dailyDoseTimes[index])
        } set: { date in
            guard viewModel.dailyDoseTimes.indices.contains(index),
                  let doseTime = MedicationDoseTimeDateBridge.doseTime(from: date) else {
                return
            }

            viewModel.dailyDoseTimes[index] = doseTime
            viewModel.dailyDoseTimes.sort {
                ($0.hour, $0.minute) < ($1.hour, $1.minute)
            }
        }
    }

    private func addDefaultDoseTime() {
        guard let doseTime = DoseTime(hour: 9, minute: 0) else {
            return
        }

        viewModel.addDoseTime(doseTime)
    }

    private func save() async {
        guard let medication = await viewModel.save() else {
            presentErrorIfNeeded()
            return
        }

        onCompletion(.saved(medication))
        dismiss()
    }

    private func deactivate() async {
        guard let medication = await viewModel.deactivate() else {
            presentErrorIfNeeded()
            return
        }

        onCompletion(.deactivated(medication))
        dismiss()
    }

    private func presentErrorIfNeeded() {
        isShowingError = viewModel.errorMessage != nil
    }
}
