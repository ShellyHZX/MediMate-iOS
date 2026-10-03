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
        .background(MediMateTheme.background)
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 8)
                    .accessibilityLabel("Refreshing activity")
            }
        }
    }

    private var emptyState: some View {
        MediMateEmptyState(
            title: "No activity yet",
            message: "Recorded medication activity will appear here.",
            systemImage: "clock.badge.checkmark"
        )
        .refreshable {
            await viewModel.loadHistory()
        }
    }

    private func errorState(message: String) -> some View {
        MediMateEmptyState(
            title: "Unable to load activity",
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
                    .foregroundStyle(MediMateTheme.secondaryText)
            }

            if let correctionMessage {
                Text(correctionMessage)
                    .font(.subheadline)
                    .foregroundStyle(MediMateTheme.secondaryText)
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
        .background(MediMateTheme.surface, in: RoundedRectangle(cornerRadius: MediMateTheme.compactCornerRadius))
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
                .foregroundStyle(MediMateTheme.primaryText)
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
            .background(MediMateTheme.surface, in: RoundedRectangle(cornerRadius: MediMateTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: MediMateTheme.cornerRadius)
                    .stroke(MediMateTheme.border, lineWidth: 1)
            }
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
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(MediMateTheme.accent)
                        .frame(width: 9, height: 9)
                        .padding(.top, 8)

                    Text(ActivityFormatter.time(moment.scheduledAt))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MediMateTheme.primaryText)
                }

                Spacer(minLength: 12)

                Text(moment.summary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MediMateTheme.secondaryText)
                    .multilineTextAlignment(.trailing)
            }

            Text(ActivityFormatter.recordCount(moment.recordCount))
                .font(.subheadline)
                .foregroundStyle(MediMateTheme.secondaryText)

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
                    .foregroundStyle(MediMateTheme.primaryText)

                Text(MedicationPresentationFormatter.dosage(dose.dosage))
                    .font(.subheadline)
                    .foregroundStyle(MediMateTheme.secondaryText)
            }

            Spacer(minLength: 8)

            MediMateStatusBadge(status: dose.status, compact: true)

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
                            .foregroundStyle(MediMateTheme.accent)
                    }
                }
            .disabled(isActionInProgress)
            .accessibilityLabel("Correct record")
        }
        .accessibilityElement(children: .combine)
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
