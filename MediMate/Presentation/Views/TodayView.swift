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
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadToday()
        }
        .refreshable {
            await viewModel.loadToday()
        }
    }

    private var todayContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header

            if viewModel.errorMessage != nil || viewModel.actionErrorMessage != nil {
                    MediMateSurface(style: .flat) {
                        VStack(alignment: .leading, spacing: 10) {
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                    .foregroundStyle(MediMateTheme.secondaryText)
                        }

                        if let actionErrorMessage = viewModel.actionErrorMessage {
                            Text(actionErrorMessage)
                                .font(.subheadline)
                                    .foregroundStyle(MediMateTheme.secondaryText)
                        }

                        Button("Retry") {
                            Task {
                                await viewModel.retry()
                            }
                        }
                    }
                }
            }

                if let priorityMoment = viewModel.priorityMoment {
                    MedicationMomentView(
                        moment: priorityMoment,
                        isPriority: true,
                        isActionInProgress: viewModel.actionInProgressMomentID == priorityMoment.id,
                        markMomentAsTaken: {
                            await viewModel.markMomentAsTaken(priorityMoment)
                        },
                        isDoseActionInProgress: { dose in
                            viewModel.actionInProgressDoseID == dose.id || viewModel.actionInProgressMomentID == priorityMoment.id
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

                let laterMoments = viewModel.medicationMoments.filter { !viewModel.isPriorityMoment($0) }
                if !laterMoments.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Later")
                            .font(.headline)
                            .foregroundStyle(MediMateTheme.primaryText)

                        MediMateSurface(style: .standard) {
                            VStack(spacing: 0) {
                                ForEach(laterMoments) { moment in
                                    LaterMomentRow(moment: moment)

                                    if moment.id != laterMoments.last?.id {
                                        Divider()
                                            .padding(.leading, 4)
                                    }
                                }
                            }
                        }
                    }
                }

                progressView
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .background(MediMateTheme.background)
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 8)
                    .accessibilityLabel("Refreshing today")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Today")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(MediMateTheme.primaryText)

            Spacer()

            Text(todayDateText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MediMateTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(viewModel.completedCount) of \(viewModel.totalCount) doses recorded today")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MediMateTheme.secondaryText)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MediMateTheme.border)

                    Capsule()
                        .fill(MediMateTheme.accent)
                        .frame(width: proxy.size.width * progressFraction)
                }
            }
            .frame(height: 5)
        }
        .accessibilityElement(children: .combine)
    }

    private var progressText: String {
        "\(viewModel.completedCount) of \(viewModel.totalCount) taken"
    }

    private var progressFraction: CGFloat {
        guard viewModel.totalCount > 0 else {
            return 0
        }

        return CGFloat(viewModel.completedCount) / CGFloat(viewModel.totalCount)
    }

    private var todayDateText: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        formatter.locale = .autoupdatingCurrent
        return formatter.string(from: Date())
    }

    private var emptyState: some View {
        MediMateEmptyState(
            title: "No doses scheduled today",
            message: "You're all set for today.",
            systemImage: "checkmark.circle"
        )
        .refreshable {
            await viewModel.loadToday()
        }
    }

    private func errorState(message: String) -> some View {
        MediMateEmptyState(
            title: "Unable to load today",
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
        MediMateSurface(style: isPriority ? .highlighted : .standard) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(TodayDoseFormatter.time(moment.scheduledAt))
                        .font(isPriority ? .system(size: 38, weight: .bold, design: .default) : .title2.weight(.bold))
                        .foregroundStyle(MediMateTheme.primaryText)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 12)

                    MediMateStatusBadge(status: momentStatus, compact: !isPriority)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(isPriority ? TodayDoseFormatter.prioritySubtitle(moment) : TodayDoseFormatter.momentStatus(moment))
                        .font(.headline)
                        .foregroundStyle(MediMateTheme.primaryText)

                    Text(TodayDoseFormatter.medicationCount(moment.scheduledMedicationCount))
                        .font(.subheadline)
                        .foregroundStyle(MediMateTheme.secondaryText)
                }

                VStack(spacing: 12) {
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
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(TodayDoseFormatter.batchActionTitle(for: moment), systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(MediMateTheme.accent)
                    .disabled(isActionInProgress)
                    .accessibilityLabel(TodayDoseFormatter.batchAccessibilityLabel(for: moment))
                } else {
                    Label("Moment reviewed", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MediMateTheme.secondaryText)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(TodayDoseFormatter.time(moment.scheduledAt)), \(TodayDoseFormatter.medicationCount(moment.scheduledMedicationCount))")
    }

    private var momentStatus: DoseStatus {
        TodayDoseFormatter.representativeStatus(for: moment)
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
            MedicationGlyph(seed: dose.medicationName)

            VStack(alignment: .leading, spacing: 4) {
                Text(dose.medicationName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MediMateTheme.primaryText)

                Text(MedicationPresentationFormatter.dosage(dose.dosage))
                    .font(.body)
                    .foregroundStyle(MediMateTheme.secondaryText)
            }

            Spacer(minLength: 8)

            if !TodayDoseFormatter.isActionable(dose.status) {
                MediMateStatusBadge(status: dose.status, compact: true)
            }

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
                            .font(.title2)
                            .foregroundStyle(MediMateTheme.accent)
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
                            .font(.title2)
                            .foregroundStyle(MediMateTheme.accent)
                    }
                }
                .disabled(isActionInProgress)
                .accessibilityLabel("Dose correction actions")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct LaterMomentRow: View {
    let moment: MedicationMoment

    var body: some View {
        HStack(spacing: 14) {
            Text(TodayDoseFormatter.time(moment.scheduledAt))
                .font(.headline.weight(.semibold))
                .foregroundStyle(MediMateTheme.primaryText)
                .frame(minWidth: 76, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(TodayDoseFormatter.medicationCount(moment.scheduledMedicationCount))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MediMateTheme.primaryText)

                Text(moment.doses.map(\.medicationName).joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(MediMateTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            MediMateStatusBadge(status: TodayDoseFormatter.representativeStatus(for: moment), compact: true)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
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

    static func prioritySubtitle(_ moment: MedicationMoment) -> String {
        switch representativeStatus(for: moment) {
        case .due, .missed:
            return "Due now"
        case .upcoming:
            return "Upcoming"
        case .taken, .skipped:
            return "Reviewed"
        }
    }

    static func representativeStatus(for moment: MedicationMoment) -> DoseStatus {
        let statuses = moment.doses.map(\.status)

        if statuses.contains(.due) || statuses.contains(.missed) {
            return .due
        }

        if statuses.contains(.upcoming) {
            return .upcoming
        }

        if statuses.contains(.taken) {
            return .taken
        }

        return .skipped
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
