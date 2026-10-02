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

    @Test func markingActionableDoseAsTakenPersistsAndReloadsToday() async throws {
        let repository = MockScheduledDoseRepository()
        let actionDate = TestDates.date(2026, 5, 4, 12, 5)
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007501"),
            scheduledAt: TestDates.date(2026, 5, 4, 8, 0),
            status: .upcoming
        )
        repository.scheduledDoseByID[dose.id] = dose
        repository.scheduledDosesInRange = [dose]
        let viewModel = makeViewModel(repository: repository, actionDate: actionDate)

        await viewModel.loadToday()
        let loadedDose = try #require(viewModel.doses.first)
        await viewModel.markDoseAsTaken(loadedDose)

        #expect(repository.fetchedScheduledDoseIDs == [dose.id])
        #expect(repository.savedScheduledDoses.first?.status == .taken)
        #expect(repository.savedScheduledDoses.first?.takenAt == actionDate)
        #expect(repository.fetchedRangeRequests.count == 2)
        #expect(viewModel.doses.first?.status == .taken)
        #expect(viewModel.completedCount == 1)
        #expect(viewModel.actionInProgressDoseID == nil)
        #expect(viewModel.actionErrorMessage == nil)
    }

    @Test func successfulTakenActionUpdatesCompletedCountAndPriorityDose() async throws {
        let repository = MockScheduledDoseRepository()
        let morningDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007601"),
            scheduledAt: TestDates.date(2026, 5, 4, 8, 0),
            status: .upcoming
        )
        let eveningDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007602"),
            scheduledAt: TestDates.date(2026, 5, 4, 18, 0),
            status: .upcoming
        )
        repository.scheduledDoseByID[morningDose.id] = morningDose
        repository.scheduledDoseByID[eveningDose.id] = eveningDose
        repository.scheduledDosesInRange = [morningDose, eveningDose]
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadToday()
        let priorityDose = try #require(viewModel.priorityDose)
        await viewModel.markDoseAsTaken(priorityDose)

        #expect(viewModel.completedCount == 1)
        #expect(viewModel.priorityDose?.id == eveningDose.id)
    }

    @Test func skippingActionableDosePersistsAndReloadsToday() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007701"),
            scheduledAt: TestDates.date(2026, 5, 4, 8, 0),
            status: .upcoming
        )
        repository.scheduledDoseByID[dose.id] = dose
        repository.scheduledDosesInRange = [dose]
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadToday()
        let loadedDose = try #require(viewModel.doses.first)
        await viewModel.skipDose(loadedDose)

        #expect(repository.fetchedScheduledDoseIDs == [dose.id])
        #expect(repository.savedScheduledDoses.first?.status == .skipped)
        #expect(repository.fetchedRangeRequests.count == 2)
        #expect(viewModel.doses.first?.status == .skipped)
        #expect(viewModel.completedCount == 0)
        #expect(viewModel.actionInProgressDoseID == nil)
    }

    @Test func skippedDoseDoesNotIncreaseCompletedCountAndPriorityMovesForward() async throws {
        let repository = MockScheduledDoseRepository()
        let morningDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007801"),
            scheduledAt: TestDates.date(2026, 5, 4, 8, 0),
            status: .upcoming
        )
        let eveningDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007802"),
            scheduledAt: TestDates.date(2026, 5, 4, 18, 0),
            status: .upcoming
        )
        repository.scheduledDoseByID[morningDose.id] = morningDose
        repository.scheduledDoseByID[eveningDose.id] = eveningDose
        repository.scheduledDosesInRange = [morningDose, eveningDose]
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadToday()
        let priorityDose = try #require(viewModel.priorityDose)
        await viewModel.skipDose(priorityDose)

        #expect(viewModel.completedCount == 0)
        #expect(viewModel.priorityDose?.id == eveningDose.id)
    }

    @Test func actionErrorMapsToHumanFacingMessage() async throws {
        let repository = MockScheduledDoseRepository()
        let skippedDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007901"),
            scheduledAt: TestDates.date(2026, 5, 4, 8, 0),
            status: .skipped
        )
        repository.scheduledDoseByID[skippedDose.id] = skippedDose
        let viewModel = makeViewModel(repository: repository)

        await viewModel.markDoseAsTaken(skippedDose)

        #expect(viewModel.actionErrorMessage == "This dose was already skipped.")
        #expect(repository.savedScheduledDoses.isEmpty)
        #expect(viewModel.actionInProgressDoseID == nil)
    }

    @Test func terminalDoseSkipErrorIsHandled() async throws {
        let repository = MockScheduledDoseRepository()
        let takenDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000007A01"),
            scheduledAt: TestDates.date(2026, 5, 4, 8, 0),
            status: .taken
        )
        repository.scheduledDoseByID[takenDose.id] = takenDose
        let viewModel = makeViewModel(repository: repository)

        await viewModel.skipDose(takenDose)

        #expect(viewModel.actionErrorMessage == "This dose is already marked as taken.")
        #expect(repository.savedScheduledDoses.isEmpty)
        #expect(viewModel.actionInProgressDoseID == nil)
    }

    private func makeViewModel(
        repository: MockScheduledDoseRepository,
        referenceDate: Date = TestDates.date(2026, 5, 4, 12, 0),
        actionDate: Date = TestDates.date(2026, 5, 4, 12, 15)
    ) -> TodayViewModel {
        TodayViewModel(
            reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase(
                scheduledDoseRepository: repository,
                calendar: TestDates.calendar
            ),
            recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase(
                scheduledDoseRepository: repository
            ),
            skipScheduledDoseUseCase: SkipScheduledDoseUseCase(
                scheduledDoseRepository: repository
            ),
            referenceDateProvider: { referenceDate },
            actionDateProvider: { actionDate }
        )
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}
