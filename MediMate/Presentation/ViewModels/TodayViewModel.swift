import Combine
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var summary: DailyMedicationSummary?
    @Published private(set) var isLoading: Bool
    @Published private(set) var actionInProgressDoseID: UUID?
    @Published private(set) var actionInProgressMomentID: Date?
    @Published var errorMessage: String?
    @Published var actionErrorMessage: String?

    private let reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase
    private let recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase
    private let recordMedicationMomentAsTakenUseCase: RecordMedicationMomentAsTakenUseCase
    private let skipScheduledDoseUseCase: SkipScheduledDoseUseCase
    private let correctDoseRecordUseCase: CorrectDoseRecordUseCase
    private let widgetSnapshotSynchronizer: WidgetSnapshotSynchronizing?
    private let calendar: Calendar
    private let referenceDateProvider: () -> Date
    private let actionDateProvider: () -> Date

    var doses: [ScheduledDose] {
        summary?.doses ?? []
    }

    var completedCount: Int {
        summary?.completedCount ?? 0
    }

    var totalCount: Int {
        summary?.totalCount ?? 0
    }

    var priorityDose: ScheduledDose? {
        summary?.priorityDose
    }

    var medicationMoments: [MedicationMoment] {
        var dosesByMoment: [Date: [ScheduledDose]] = [:]

        for dose in doses {
            let momentDate = calendarMinute(for: dose.scheduledAt)
            dosesByMoment[momentDate, default: []].append(dose)
        }

        return dosesByMoment
            .map { scheduledAt, doses in
                MedicationMoment(
                    scheduledAt: scheduledAt,
                    doses: doses.sorted {
                        if $0.medicationName == $1.medicationName {
                            return $0.id.uuidString < $1.id.uuidString
                        }

                        return $0.medicationName.localizedStandardCompare($1.medicationName) == .orderedAscending
                    }
                )
            }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var priorityMoment: MedicationMoment? {
        guard let priorityDose else {
            return nil
        }

        return medicationMoments.first { moment in
            moment.doses.contains { $0.id == priorityDose.id }
        }
    }

    var hasDoses: Bool {
        !doses.isEmpty
    }

    init(
        reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase,
        recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase,
        recordMedicationMomentAsTakenUseCase: RecordMedicationMomentAsTakenUseCase,
        skipScheduledDoseUseCase: SkipScheduledDoseUseCase,
        correctDoseRecordUseCase: CorrectDoseRecordUseCase,
        widgetSnapshotSynchronizer: WidgetSnapshotSynchronizing? = nil,
        calendar: Calendar,
        referenceDateProvider: @escaping () -> Date = Date.init,
        actionDateProvider: @escaping () -> Date = Date.init,
        summary: DailyMedicationSummary? = nil,
        isLoading: Bool = false,
        actionInProgressDoseID: UUID? = nil,
        actionInProgressMomentID: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.reviewTodaysMedicationUseCase = reviewTodaysMedicationUseCase
        self.recordDoseAsTakenUseCase = recordDoseAsTakenUseCase
        self.recordMedicationMomentAsTakenUseCase = recordMedicationMomentAsTakenUseCase
        self.skipScheduledDoseUseCase = skipScheduledDoseUseCase
        self.correctDoseRecordUseCase = correctDoseRecordUseCase
        self.widgetSnapshotSynchronizer = widgetSnapshotSynchronizer
        self.calendar = calendar
        self.referenceDateProvider = referenceDateProvider
        self.actionDateProvider = actionDateProvider
        self.summary = summary
        self.isLoading = isLoading
        self.actionInProgressDoseID = actionInProgressDoseID
        self.actionInProgressMomentID = actionInProgressMomentID
        self.errorMessage = errorMessage
        self.actionErrorMessage = nil
    }

    func loadToday() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let referenceDate = referenceDateProvider()
            summary = try await reviewTodaysMedicationUseCase.execute(referenceDate: referenceDate)
            await syncWidgetSnapshot(referenceDate: referenceDate)
        } catch let error as ReviewTodaysMedicationUseCaseError {
            errorMessage = mapError(error)
        } catch {
            errorMessage = "We couldn't load today's medications. Please try again."
        }
    }

    func retry() async {
        await loadToday()
    }

    func markDoseAsTaken(_ dose: ScheduledDose) async {
        guard actionInProgressDoseID == nil, actionInProgressMomentID == nil else {
            return
        }

        actionInProgressDoseID = dose.id
        actionErrorMessage = nil

        defer {
            actionInProgressDoseID = nil
        }

        do {
            _ = try await recordDoseAsTakenUseCase.execute(
                scheduledDoseID: dose.id,
                takenAt: actionDateProvider()
            )
            await syncWidgetSnapshot(referenceDate: referenceDateProvider())
            await loadToday()
        } catch let error as RecordDoseAsTakenUseCaseError {
            actionErrorMessage = mapError(error)
        } catch {
            actionErrorMessage = "We couldn't update this dose. Please try again."
        }
    }

    func skipDose(_ dose: ScheduledDose) async {
        guard actionInProgressDoseID == nil, actionInProgressMomentID == nil else {
            return
        }

        actionInProgressDoseID = dose.id
        actionErrorMessage = nil

        defer {
            actionInProgressDoseID = nil
        }

        do {
            _ = try await skipScheduledDoseUseCase.execute(scheduledDoseID: dose.id)
            await syncWidgetSnapshot(referenceDate: referenceDateProvider())
            await loadToday()
        } catch let error as SkipScheduledDoseUseCaseError {
            actionErrorMessage = mapError(error)
        } catch {
            actionErrorMessage = "We couldn't update this dose. Please try again."
        }
    }

    func undoDoseRecord(_ dose: ScheduledDose) async {
        guard actionInProgressDoseID == nil, actionInProgressMomentID == nil else {
            return
        }

        actionInProgressDoseID = dose.id
        actionErrorMessage = nil

        defer {
            actionInProgressDoseID = nil
        }

        do {
            _ = try await correctDoseRecordUseCase.execute(
                scheduledDoseID: dose.id,
                correction: .notTaken,
                referenceDate: referenceDateProvider()
            )
            await syncWidgetSnapshot(referenceDate: referenceDateProvider())
            await loadToday()
        } catch let error as CorrectDoseRecordUseCaseError {
            actionErrorMessage = mapError(error)
        } catch {
            actionErrorMessage = "We couldn't correct this dose. Please try again."
        }
    }

    func markMomentAsTaken(_ moment: MedicationMoment) async {
        guard actionInProgressDoseID == nil, actionInProgressMomentID == nil else {
            return
        }

        let unresolvedDoses = moment.unresolvedDoses

        guard !unresolvedDoses.isEmpty else {
            return
        }

        actionInProgressMomentID = moment.id
        actionErrorMessage = nil

        defer {
            actionInProgressMomentID = nil
        }

        do {
            _ = try await recordMedicationMomentAsTakenUseCase.execute(
                scheduledDoseIDs: unresolvedDoses.map(\.id),
                takenAt: actionDateProvider()
            )
            await syncWidgetSnapshot(referenceDate: referenceDateProvider())
            await loadToday()
        } catch let error as RecordMedicationMomentAsTakenUseCaseError {
            actionErrorMessage = mapError(error)
        } catch {
            actionErrorMessage = "We couldn't update these doses. Please try again."
        }
    }

    func isPriorityMoment(_ moment: MedicationMoment) -> Bool {
        priorityMoment?.id == moment.id
    }

    private func mapError(_ error: ReviewTodaysMedicationUseCaseError) -> String {
        switch error {
        case .invalidDateCalculation:
            return "We couldn't prepare today's medication schedule. Please try again."
        case .persistenceFailure:
            return "We couldn't load today's medications. Please try again."
        }
    }

    private func mapError(_ error: RecordDoseAsTakenUseCaseError) -> String {
        switch error {
        case .alreadyTaken:
            return "This dose is already marked as taken."
        case .doseWasSkipped:
            return "This dose was already skipped."
        case .doseNotFound:
            return "This dose is no longer available."
        case .persistenceFailure:
            return "We couldn't update this dose. Please try again."
        }
    }

    private func mapError(_ error: SkipScheduledDoseUseCaseError) -> String {
        switch error {
        case .doseAlreadyTaken:
            return "This dose is already marked as taken."
        case .doseAlreadySkipped:
            return "This dose was already skipped."
        case .doseNotFound:
            return "This dose is no longer available."
        case .persistenceFailure:
            return "We couldn't update this dose. Please try again."
        }
    }

    private func mapError(_ error: CorrectDoseRecordUseCaseError) -> String {
        switch error {
        case .doseNotFound:
            return "This dose is no longer available."
        case .persistenceFailure:
            return "We couldn't correct this dose. Please try again."
        }
    }

    private func mapError(_ error: RecordMedicationMomentAsTakenUseCaseError) -> String {
        switch error {
        case .emptyDoseSelection:
            return "There are no doses to mark as taken."
        case .doseNotFound:
            return "One of these doses is no longer available."
        case .doseAlreadyTaken:
            return "One of these doses is already marked as taken."
        case .doseWasSkipped:
            return "One of these doses was already skipped."
        case .persistenceFailure:
            return "We couldn't update these doses. Please try again."
        }
    }

    private func calendarMinute(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }

    private func syncWidgetSnapshot(referenceDate: Date) async {
        await widgetSnapshotSynchronizer?.sync(referenceDate: referenceDate)
    }
}
