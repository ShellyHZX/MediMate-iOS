import Combine
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var summary: DailyMedicationSummary?
    @Published private(set) var isLoading: Bool
    @Published private(set) var actionInProgressDoseID: UUID?
    @Published var errorMessage: String?
    @Published var actionErrorMessage: String?

    private let reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase
    private let recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase
    private let skipScheduledDoseUseCase: SkipScheduledDoseUseCase
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

    var hasDoses: Bool {
        !doses.isEmpty
    }

    init(
        reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase,
        recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase,
        skipScheduledDoseUseCase: SkipScheduledDoseUseCase,
        referenceDateProvider: @escaping () -> Date = Date.init,
        actionDateProvider: @escaping () -> Date = Date.init,
        summary: DailyMedicationSummary? = nil,
        isLoading: Bool = false,
        actionInProgressDoseID: UUID? = nil,
        errorMessage: String? = nil
    ) {
        self.reviewTodaysMedicationUseCase = reviewTodaysMedicationUseCase
        self.recordDoseAsTakenUseCase = recordDoseAsTakenUseCase
        self.skipScheduledDoseUseCase = skipScheduledDoseUseCase
        self.referenceDateProvider = referenceDateProvider
        self.actionDateProvider = actionDateProvider
        self.summary = summary
        self.isLoading = isLoading
        self.actionInProgressDoseID = actionInProgressDoseID
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
            summary = try await reviewTodaysMedicationUseCase.execute(referenceDate: referenceDateProvider())
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
        guard actionInProgressDoseID == nil else {
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
            await loadToday()
        } catch let error as RecordDoseAsTakenUseCaseError {
            actionErrorMessage = mapError(error)
        } catch {
            actionErrorMessage = "We couldn't update this dose. Please try again."
        }
    }

    func skipDose(_ dose: ScheduledDose) async {
        guard actionInProgressDoseID == nil else {
            return
        }

        actionInProgressDoseID = dose.id
        actionErrorMessage = nil

        defer {
            actionInProgressDoseID = nil
        }

        do {
            _ = try await skipScheduledDoseUseCase.execute(scheduledDoseID: dose.id)
            await loadToday()
        } catch let error as SkipScheduledDoseUseCaseError {
            actionErrorMessage = mapError(error)
        } catch {
            actionErrorMessage = "We couldn't update this dose. Please try again."
        }
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
}
