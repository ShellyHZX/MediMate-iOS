import Combine
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var summary: DailyMedicationSummary?
    @Published private(set) var isLoading: Bool
    @Published var errorMessage: String?

    private let reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase
    private let referenceDateProvider: () -> Date

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
        referenceDateProvider: @escaping () -> Date = Date.init,
        summary: DailyMedicationSummary? = nil,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.reviewTodaysMedicationUseCase = reviewTodaysMedicationUseCase
        self.referenceDateProvider = referenceDateProvider
        self.summary = summary
        self.isLoading = isLoading
        self.errorMessage = errorMessage
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

    private func mapError(_ error: ReviewTodaysMedicationUseCaseError) -> String {
        switch error {
        case .invalidDateCalculation:
            return "We couldn't prepare today's medication schedule. Please try again."
        case .persistenceFailure:
            return "We couldn't load today's medications. Please try again."
        }
    }
}
