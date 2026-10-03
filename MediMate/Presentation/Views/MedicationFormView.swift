import SwiftUI

struct MedicationFormView: View {
    enum Completion {
        case saved(Medication)
        case deactivated(Medication)
        case deleted
    }

    @StateObject private var viewModel: MedicationFormViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDeactivationConfirmation = false
    @State private var isShowingDeletionConfirmation = false
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                medicationSection
                dosageSection
                scheduleSection
                instructionsSection

                if viewModel.isDeactivationAvailable || viewModel.isDeletionAvailable {
                    managementSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(MediMateTheme.background)
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
        .confirmationDialog(
            "Delete this medication?",
            isPresented: $isShowingDeletionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Medication", role: .destructive) {
                Task {
                    await deleteMedication()
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently removes the medication and its unused scheduled doses. This can't be undone.")
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
        FormSection(title: "Medication") {
            LabeledInput(title: "Name") {
                TextField("Medication name", text: $viewModel.name)
                    .textContentType(.name)
                    .textFieldStyle(.plain)
            }
        }
    }

    private var dosageSection: some View {
        FormSection(title: "Dosage") {
            LabeledInput(title: "Amount") {
                TextField("Amount", text: $viewModel.dosageAmountText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
            }

            LabeledInput(title: "Unit") {
                Picker("Unit", selection: $viewModel.dosageUnit) {
                    ForEach(DosageUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue)
                            .tag(unit)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var scheduleSection: some View {
        FormSection(title: "Schedule") {
            FormValueRow(title: "Repeats", value: "Every day")

            if viewModel.dailyDoseTimes.isEmpty {
                Text("Add at least one dose time.")
                    .font(.body)
                    .foregroundStyle(MediMateTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .accessibilityLabel("Add at least one dose time")
            } else {
                ForEach(viewModel.dailyDoseTimes.indices, id: \.self) { index in
                    doseTimeRow(index: index)
                }
            }

            Button {
                addDefaultDoseTime()
            } label: {
                Label("Add Time", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tint(MediMateTheme.accent)
            .padding(.top, 4)
            .accessibilityLabel("Add dose time")
        }
    }

    private var instructionsSection: some View {
        FormSection(title: "Instructions") {
            LabeledInput(title: "Optional notes") {
                TextField("Optional instructions", text: $viewModel.instructions, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.plain)
            }
        }
    }

    private var managementSection: some View {
        FormSection(title: "Manage Medication") {
            if viewModel.isDeactivationAvailable {
                Button {
                    isShowingDeactivationConfirmation = true
                } label: {
                    Label("Deactivate Medication", systemImage: "pause.circle")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tint(MediMateTheme.accent)
                .disabled(viewModel.isSaving)
                .accessibilityLabel("Deactivate Medication")
            }

            if viewModel.isDeletionAvailable {
                Button(role: .destructive) {
                    isShowingDeletionConfirmation = true
                } label: {
                    Label("Delete Medication", systemImage: "trash")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tint(.red)
                .disabled(viewModel.isSaving)
                .accessibilityLabel("Delete Medication")

                Text("Only medications without recorded dose history can be permanently deleted.")
                    .font(.footnote)
                    .foregroundStyle(MediMateTheme.secondaryText)
            }
        }
    }

    private func doseTimeRow(index: Int) -> some View {
        HStack(spacing: 12) {
            DatePicker(
                "Dose Time",
                selection: doseTimeBinding(for: index),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .accessibilityLabel("Dose time \(index + 1)")

            Spacer(minLength: 8)

            Button(role: .destructive) {
                viewModel.removeDoseTime(at: index)
            } label: {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel("Remove dose time \(index + 1)")
        }
        .padding(12)
        .background(MediMateTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: MediMateTheme.compactCornerRadius))
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

    private func deleteMedication() async {
        guard await viewModel.deleteMedication() else {
            presentErrorIfNeeded()
            return
        }

        onCompletion(.deleted)
        dismiss()
    }

    private func presentErrorIfNeeded() {
        isShowingError = viewModel.errorMessage != nil
    }
}

private struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(MediMateTheme.secondaryText)
                .accessibilityAddTraits(.isHeader)

            MediMateSurface(style: .standard) {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
            }
        }
    }
}

private struct LabeledInput<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MediMateTheme.secondaryText)

            content
                .font(.body)
                .foregroundStyle(MediMateTheme.primaryText)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MediMateTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: MediMateTheme.compactCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: MediMateTheme.compactCornerRadius)
                        .stroke(MediMateTheme.border, lineWidth: 1)
                }
        }
    }
}

private struct FormValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(MediMateTheme.primaryText)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundStyle(MediMateTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }
}
