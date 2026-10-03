import SwiftUI

struct ActivityView: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        Group {
            if viewModel.doses.isEmpty, viewModel.isLoading {
                ProgressView("Loading activity")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.doses.isEmpty, let errorMessage = viewModel.errorMessage {
                errorState(message: errorMessage)
            } else if viewModel.activityDaySections.isEmpty {
                emptyState
            } else {
                activityContent
            }
        }
        .navigationTitle("Activity")
        .task {
            await viewModel.loadHistory()
        }
        .refreshable {
            await viewModel.loadHistory()
        }
    }

    private var activityContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18, pinnedViews: []) {
                if viewModel.errorMessage != nil || viewModel.correctionErrorMessage != nil {
                    ActivityMessageView(
                        loadMessage: viewModel.errorMessage,
                        correctionMessage: viewModel.correctionErrorMessage,
                        retry: {
                            await viewModel.retry()
                        }
                    )
                }

                ForEach(viewModel.activityDaySections) { section in
                    ActivityDayView(
                        section: section,
                        title: viewModel.activityDayTitle(for: section.date),
                        actionInProgressDoseID: viewModel.actionInProgressDoseID,
                        correctRecord: { dose in
                            await viewModel.markRecordAsNotTaken(dose)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 8)
                    .accessibilityLabel("Refreshing activity")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No activity yet", systemImage: "clock.badge.checkmark")
        } description: {
            Text("Your recorded medication activity will appear here.")
        }
        .refreshable {
            await viewModel.loadHistory()
        }
    }

    private func errorState(message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to load activity", systemImage: "exclamationmark.circle")
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

private struct ActivityMessageView: View {
    let loadMessage: String?
    let correctionMessage: String?
    let retry: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let loadMessage {
                Text(loadMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let correctionMessage {
                Text(correctionMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if loadMessage != nil {
                Button("Retry") {
                    Task {
                        await retry()
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ActivityDayView: View {
    let section: ActivityDaySection
    let title: String
    let actionInProgressDoseID: UUID?
    let correctRecord: (ScheduledDose) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(section.moments) { moment in
                    ActivityMomentView(
                        moment: moment,
                        actionInProgressDoseID: actionInProgressDoseID,
                        correctRecord: correctRecord
                    )

                    if moment.id != section.moments.last?.id {
                        Divider()
                            .padding(.leading, 18)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ActivityMomentView: View {
    let moment: ActivityMoment
    let actionInProgressDoseID: UUID?
    let correctRecord: (ScheduledDose) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(ActivityFormatter.time(moment.scheduledAt))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                Text(moment.summary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            Text(ActivityFormatter.recordCount(moment.recordCount))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(moment.doses) { dose in
                    ActivityDoseRow(
                        dose: dose,
                        isActionInProgress: actionInProgressDoseID == dose.id,
                        correctRecord: {
                            await correctRecord(dose)
                        }
                    )
                }
            }
        }
        .padding(14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(ActivityFormatter.time(moment.scheduledAt)), \(ActivityFormatter.recordCount(moment.recordCount)), \(moment.summary)")
    }
}

private struct ActivityDoseRow: View {
    let dose: ScheduledDose
    let isActionInProgress: Bool
    let correctRecord: () async -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ActivityFormatter.statusSystemImage(dose.status))
                .font(.body.weight(.semibold))
                .foregroundStyle(ActivityFormatter.statusColor(dose.status))
                .frame(width: 22, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(dose.medicationName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(MedicationPresentationFormatter.dosage(dose.dosage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            ActivityStatusLabel(status: dose.status)

            Menu {
                Button {
                    Task {
                        await correctRecord()
                    }
                } label: {
                    Label("Mark as not taken", systemImage: "arrow.uturn.backward")
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
            .accessibilityLabel("Correct record")
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ActivityStatusLabel: View {
    let status: DoseStatus

    var body: some View {
        Label {
            Text(ActivityFormatter.status(status))
                .font(.caption.weight(.semibold))
        } icon: {
            Image(systemName: ActivityFormatter.statusSystemImage(status))
                .font(.caption)
        }
        .foregroundStyle(ActivityFormatter.statusColor(status))
        .labelStyle(.titleAndIcon)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(ActivityFormatter.status(status))
    }
}

private enum ActivityFormatter {
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = .autoupdatingCurrent
        return formatter.string(from: date)
    }

    static func recordCount(_ count: Int) -> String {
        if count == 1 {
            return "1 medication recorded"
        }

        return "\(count) medications recorded"
    }

    static func status(_ status: DoseStatus) -> String {
        switch status {
        case .taken:
            return "Taken"
        case .skipped:
            return "Skipped"
        case .missed:
            return "Missed"
        case .upcoming:
            return "Upcoming"
        case .due:
            return "Due"
        }
    }

    static func statusSystemImage(_ status: DoseStatus) -> String {
        switch status {
        case .taken:
            return "checkmark.circle"
        case .skipped:
            return "minus.circle"
        case .missed:
            return "xmark.circle"
        case .upcoming:
            return "clock"
        case .due:
            return "exclamationmark.circle"
        }
    }

    static func statusColor(_ status: DoseStatus) -> Color {
        switch status {
        case .taken:
            return .green
        case .skipped:
            return .secondary
        case .missed:
            return .orange
        case .upcoming:
            return .secondary
        case .due:
            return .orange
        }
    }
}
