import SwiftUI

struct TodayView: View {
    @ObservedObject var viewModel: TodayViewModel

    var body: some View {
        Group {
            if viewModel.summary == nil, viewModel.isLoading {
                ProgressView("Loading today")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.summary == nil, let errorMessage = viewModel.errorMessage {
                errorState(message: errorMessage)
            } else if viewModel.summary != nil, !viewModel.hasDoses {
                emptyState
            } else {
                todayContent
            }
        }
        .navigationTitle("Today")
        .task {
            await viewModel.loadToday()
        }
        .refreshable {
            await viewModel.loadToday()
        }
    }

    private var todayContent: some View {
        List {
            if viewModel.errorMessage != nil || viewModel.actionErrorMessage != nil {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let actionErrorMessage = viewModel.actionErrorMessage {
                            Text(actionErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Button("Retry") {
                            Task {
                                await viewModel.retry()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(progressText)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Completed today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            if let priorityDose = viewModel.priorityDose {
                Section("Priority") {
                    PriorityDoseView(
                        dose: priorityDose,
                        isActionInProgress: viewModel.actionInProgressDoseID == priorityDose.id,
                        markAsTaken: {
                            await viewModel.markDoseAsTaken(priorityDose)
                        },
                        skipDose: {
                            await viewModel.skipDose(priorityDose)
                        }
                    )
                }
            } else if viewModel.hasDoses {
                Section("Priority") {
                    Label("All doses reviewed for today", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
            }

            Section("Scheduled Today") {
                ForEach(viewModel.doses) { dose in
                    TodayDoseRow(
                        dose: dose,
                        isActionInProgress: viewModel.actionInProgressDoseID == dose.id,
                        markAsTaken: {
                            await viewModel.markDoseAsTaken(dose)
                        },
                        skipDose: {
                            await viewModel.skipDose(dose)
                        }
                    )
                }
            }
        }
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 8)
                    .accessibilityLabel("Refreshing today")
            }
        }
    }

    private var progressText: String {
        "\(viewModel.completedCount) of \(viewModel.totalCount) taken"
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No doses scheduled today", systemImage: "checkmark.circle")
        } description: {
            Text("You're all set for today.")
        }
        .refreshable {
            await viewModel.loadToday()
        }
    }

    private func errorState(message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to load today", systemImage: "exclamationmark.circle")
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

private struct PriorityDoseView: View {
    let dose: ScheduledDose
    let isActionInProgress: Bool
    let markAsTaken: () async -> Void
    let skipDose: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(TodayDoseFormatter.time(dose.scheduledAt))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                StatusLabel(status: dose.status)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dose.medicationName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(MedicationPresentationFormatter.dosage(dose.dosage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if TodayDoseFormatter.isActionable(dose.status) {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await markAsTaken()
                        }
                    } label: {
                        if isActionInProgress {
                            ProgressView()
                        } else {
                            Label("Mark as Taken", systemImage: "checkmark.circle")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isActionInProgress)

                    Button {
                        Task {
                            await skipDose()
                        }
                    } label: {
                        Label("Skip", systemImage: "minus.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isActionInProgress)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct TodayDoseRow: View {
    let dose: ScheduledDose
    let isActionInProgress: Bool
    let markAsTaken: () async -> Void
    let skipDose: () async -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(TodayDoseFormatter.time(dose.scheduledAt))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(minWidth: 72, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(dose.medicationName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(MedicationPresentationFormatter.dosage(dose.dosage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            StatusLabel(status: dose.status)

            if TodayDoseFormatter.isActionable(dose.status) {
                Menu {
                    Button {
                        Task {
                            await markAsTaken()
                        }
                    } label: {
                        Label("Mark as Taken", systemImage: "checkmark.circle")
                    }

                    Button {
                        Task {
                            await skipDose()
                        }
                    } label: {
                        Label("Skip", systemImage: "minus.circle")
                    }
                } label: {
                    if isActionInProgress {
                        ProgressView()
                    } else {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
                .disabled(isActionInProgress)
                .accessibilityLabel("Dose actions")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StatusLabel: View {
    let status: DoseStatus

    var body: some View {
        Label {
            Text(TodayDoseFormatter.status(status))
                .font(.caption.weight(.semibold))
        } icon: {
            Image(systemName: TodayDoseFormatter.statusSystemImage(status))
                .font(.caption)
        }
        .foregroundStyle(TodayDoseFormatter.statusColor(status))
        .labelStyle(.titleAndIcon)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(TodayDoseFormatter.status(status))
    }
}

private enum TodayDoseFormatter {
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = .autoupdatingCurrent
        return formatter.string(from: date)
    }

    static func status(_ status: DoseStatus) -> String {
        switch status {
        case .upcoming:
            return "Upcoming"
        case .due:
            return "Due"
        case .taken:
            return "Taken"
        case .skipped:
            return "Skipped"
        case .missed:
            return "Missed"
        }
    }

    static func statusSystemImage(_ status: DoseStatus) -> String {
        switch status {
        case .upcoming:
            return "clock"
        case .due:
            return "exclamationmark.circle"
        case .taken:
            return "checkmark.circle"
        case .skipped:
            return "minus.circle"
        case .missed:
            return "xmark.circle"
        }
    }

    static func statusColor(_ status: DoseStatus) -> Color {
        switch status {
        case .upcoming:
            return .secondary
        case .due:
            return .orange
        case .taken:
            return .green
        case .skipped:
            return .secondary
        case .missed:
            return .red
        }
    }

    static func isActionable(_ status: DoseStatus) -> Bool {
        switch status {
        case .upcoming, .due, .missed:
            return true
        case .taken, .skipped:
            return false
        }
    }
}
