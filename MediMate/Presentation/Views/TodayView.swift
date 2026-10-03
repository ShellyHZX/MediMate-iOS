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

            Section("Scheduled Today") {
                ForEach(viewModel.medicationMoments) { moment in
                    MedicationMomentView(
                        moment: moment,
                        isPriority: viewModel.isPriorityMoment(moment),
                        isActionInProgress: viewModel.actionInProgressMomentID == moment.id,
                        markMomentAsTaken: {
                            await viewModel.markMomentAsTaken(moment)
                        },
                        isDoseActionInProgress: { dose in
                            viewModel.actionInProgressDoseID == dose.id || viewModel.actionInProgressMomentID == moment.id
                        },
                        markAsTaken: { dose in
                            await viewModel.markDoseAsTaken(dose)
                        },
                        skipDose: { dose in
                            await viewModel.skipDose(dose)
                        },
                        undoDoseRecord: { dose in
                            await viewModel.undoDoseRecord(dose)
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

private struct MedicationMomentView: View {
    let moment: MedicationMoment
    let isPriority: Bool
    let isActionInProgress: Bool
    let markMomentAsTaken: () async -> Void
    let isDoseActionInProgress: (ScheduledDose) -> Bool
    let markAsTaken: (ScheduledDose) async -> Void
    let skipDose: (ScheduledDose) async -> Void
    let undoDoseRecord: (ScheduledDose) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(TodayDoseFormatter.time(moment.scheduledAt))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                if isPriority {
                    Text("Current")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(TodayDoseFormatter.momentStatus(moment))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(TodayDoseFormatter.medicationCount(moment.scheduledMedicationCount))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(moment.doses) { dose in
                    MomentDoseRow(
                        dose: dose,
                        isActionInProgress: isDoseActionInProgress(dose),
                        markAsTaken: {
                            await markAsTaken(dose)
                        },
                        skipDose: {
                            await skipDose(dose)
                        },
                        undoDoseRecord: {
                            await undoDoseRecord(dose)
                        }
                    )
                    .accessibilityElement(children: .combine)
                }
            }

            if moment.hasUnresolvedDoses {
                Button {
                    Task {
                        await markMomentAsTaken()
                    }
                } label: {
                    if isActionInProgress {
                        ProgressView()
                    } else {
                        Label(TodayDoseFormatter.batchActionTitle(for: moment), systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isActionInProgress)
                .accessibilityLabel(TodayDoseFormatter.batchAccessibilityLabel(for: moment))
            } else {
                Label("Moment reviewed", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(TodayDoseFormatter.time(moment.scheduledAt)), \(TodayDoseFormatter.medicationCount(moment.scheduledMedicationCount))")
    }
}

private struct MomentDoseRow: View {
    let dose: ScheduledDose
    let isActionInProgress: Bool
    let markAsTaken: () async -> Void
    let skipDose: () async -> Void
    let undoDoseRecord: () async -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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
            } else if TodayDoseFormatter.isCorrectable(dose.status) {
                Menu {
                    Button {
                        Task {
                            await undoDoseRecord()
                        }
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
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
                .accessibilityLabel("Dose correction actions")
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

    static func isCorrectable(_ status: DoseStatus) -> Bool {
        switch status {
        case .taken, .skipped:
            return true
        case .upcoming, .due, .missed:
            return false
        }
    }

    static func medicationCount(_ count: Int) -> String {
        if count == 1 {
            return "1 medication scheduled"
        }

        return "\(count) medications scheduled"
    }

    static func momentStatus(_ moment: MedicationMoment) -> String {
        let statuses = moment.doses.map(\.status)

        if statuses.contains(.due) || statuses.contains(.missed) {
            return "Due"
        }

        if statuses.contains(.upcoming) {
            return "Upcoming"
        }

        return "Reviewed"
    }

    static func batchActionTitle(for moment: MedicationMoment) -> String {
        if moment.unresolvedDoses.count == moment.doses.count {
            return "Mark all as taken"
        }

        return "Mark remaining as taken"
    }

    static func batchAccessibilityLabel(for moment: MedicationMoment) -> String {
        "\(batchActionTitle(for: moment)) for \(medicationCount(moment.unresolvedDoses.count)) at \(time(moment.scheduledAt))"
    }
}
