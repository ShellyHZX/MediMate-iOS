import Foundation
import Testing
@testable import MediMate

@MainActor
struct TodayViewModelTests {
    @Test func initialStateIsEmptyAndNotLoading() {
        let viewModel = makeViewModel(repository: MockScheduledDoseRepository())

        #expect(viewModel.summary == nil)
        #expect(viewModel.doses.isEmpty)
        #expect(viewModel.completedCount == 0)
        #expect(viewModel.totalCount == 0)
        #expect(viewModel.priorityDose == nil)
        #expect(!viewModel.hasDoses)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func successfulLoadPublishesDailyMedicationSummary() async throws {
        let repository = MockScheduledDoseRepository()
        let morningDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007101"),
            scheduledAt: TestDates.date(2026, 5, 4, 8, 0),
            status: .upcoming
        )
        let eveningDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007102"),
            scheduledAt: TestDates.date(2026, 5, 4, 20, 0),
            status: .upcoming
        )
        repository.scheduledDosesInRange = [eveningDose, morningDose]
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadToday()

        #expect(viewModel.summary?.doses.map(\.id) == [morningDose.id, eveningDose.id])
        #expect(viewModel.summary?.totalCount == 2)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test func derivedStateReflectsLoadedSummary() async throws {
        let repository = MockScheduledDoseRepository()
        let takenDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007201"),
            scheduledAt: TestDates.date(2026, 5, 4, 8, 0),
            status: .taken
        )
        let dueDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007202"),
            scheduledAt: TestDates.date(2026, 5, 4, 10, 0),
            status: .upcoming
        )
        let upcomingDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007203"),
            scheduledAt: TestDates.date(2026, 5, 4, 18, 0),
            status: .upcoming
        )
        repository.scheduledDosesInRange = [upcomingDose, dueDose, takenDose]
        let viewModel = makeViewModel(
            repository: repository,
            referenceDate: TestDates.date(2026, 5, 4, 12, 0)
        )

        await viewModel.loadToday()

        #expect(viewModel.doses.count == 3)
        #expect(viewModel.completedCount == 1)
        #expect(viewModel.totalCount == 3)
        #expect(viewModel.priorityDose?.id == dueDose.id)
        #expect(viewModel.hasDoses)
    }

    @Test func loadFailureExposesHumanFacingErrorAndStopsLoading() async {
        let repository = MockScheduledDoseRepository()
        repository.fetchScheduledDosesError = MockScheduledDoseRepositoryError.requestedFailure
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadToday()

        #expect(viewModel.summary == nil)
        #expect(viewModel.errorMessage == "We couldn't load today's medications. Please try again.")
        #expect(!viewModel.isLoading)
    }

    @Test func retryPerformsAnotherLoad() async throws {
        let repository = MockScheduledDoseRepository()
        repository.scheduledDosesInRange = [
            try makeScheduledDose(
                id: uuid("00000000-0000-0000-0000-000000007301"),
                scheduledAt: TestDates.date(2026, 5, 4, 8, 0),
                status: .upcoming
            )
        ]
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadToday()
        await viewModel.retry()

        #expect(repository.fetchedRangeRequests.count == 2)
        #expect(viewModel.totalCount == 1)
    }

    @Test func existingSummaryIsPreservedWhenReloadFails() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007401"),
            scheduledAt: TestDates.date(2026, 5, 4, 8, 0),
            status: .upcoming
        )
        repository.scheduledDosesInRange = [dose]
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadToday()
        let loadedSummary = try #require(viewModel.summary)
        repository.fetchScheduledDosesError = MockScheduledDoseRepositoryError.requestedFailure

        await viewModel.loadToday()

        #expect(viewModel.summary == loadedSummary)
        #expect(viewModel.errorMessage == "We couldn't load today's medications. Please try again.")
        #expect(!viewModel.isLoading)
    }

    @Test func injectedReferenceDateDeterminesFetchedDayRange() async {
        let repository = MockScheduledDoseRepository()
        let referenceDate = TestDates.date(2026, 5, 4, 15, 30)
        let viewModel = makeViewModel(repository: repository, referenceDate: referenceDate)

        await viewModel.loadToday()

        #expect(repository.fetchedRangeRequests.first?.startDate == TestDates.date(2026, 5, 4, 0, 0))
        #expect(repository.fetchedRangeRequests.first?.endDate == TestDates.date(2026, 5, 5, 0, 0))
    }

    private func makeViewModel(
        repository: MockScheduledDoseRepository,
        referenceDate: Date = TestDates.date(2026, 5, 4, 12, 0)
    ) -> TodayViewModel {
        TodayViewModel(
            reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase(
                scheduledDoseRepository: repository,
                calendar: TestDates.calendar
            ),
            referenceDateProvider: { referenceDate }
        )
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}
