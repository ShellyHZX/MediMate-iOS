import Foundation
import Testing
@testable import MediMate

@MainActor
struct HistoryViewModelTests {
    @Test func successfulLoadPublishesDoses() async throws {
        let repository = MockScheduledDoseRepository()
        let newestDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009501"),
            scheduledAt: TestDates.date(2026, 5, 20, 18, 0),
            status: .taken
        )
        let olderDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009502"),
            scheduledAt: TestDates.date(2026, 5, 19, 8, 0),
            status: .skipped
        )
        repository.scheduledDosesInRange = [olderDose, newestDose]
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadHistory()

        #expect(viewModel.doses.map(\.id) == [newestDose.id, olderDose.id])
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test func daySectionsGroupByCalendarDayWithNewestDayFirst() async throws {
        let repository = MockScheduledDoseRepository()
        let todayEveningDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009601"),
            scheduledAt: TestDates.date(2026, 5, 20, 18, 0),
            status: .taken
        )
        let todayMorningDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009602"),
            scheduledAt: TestDates.date(2026, 5, 20, 8, 0),
            status: .skipped
        )
        let yesterdayDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009603"),
            scheduledAt: TestDates.date(2026, 5, 19, 20, 0),
            status: .missed
        )
        repository.scheduledDosesInRange = [yesterdayDose, todayMorningDose, todayEveningDose]
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadHistory()

        #expect(viewModel.daySections.map(\.date) == [
            TestDates.date(2026, 5, 20, 0, 0),
            TestDates.date(2026, 5, 19, 0, 0)
        ])
        #expect(viewModel.daySections.first?.doses.map(\.id) == [todayEveningDose.id, todayMorningDose.id])
    }

    @Test func reloadFailurePreservesExistingHistoryAndExposesError() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009701"),
            scheduledAt: TestDates.date(2026, 5, 20, 18, 0),
            status: .taken
        )
        repository.scheduledDosesInRange = [dose]
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadHistory()
        repository.fetchScheduledDosesError = MockScheduledDoseRepositoryError.requestedFailure

        await viewModel.loadHistory()

        #expect(viewModel.doses == [dose])
        #expect(viewModel.errorMessage == "We couldn't load your medication history. Please try again.")
        #expect(!viewModel.isLoading)
    }

    @Test func retryPerformsAnotherLoadAndClearsStaleError() async throws {
        let repository = MockScheduledDoseRepository()
        repository.fetchScheduledDosesError = MockScheduledDoseRepositoryError.requestedFailure
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadHistory()
        repository.fetchScheduledDosesError = nil
        repository.scheduledDosesInRange = [
            try makeScheduledDose(
                id: uuid("00000000-0000-0000-0000-000000009801"),
                scheduledAt: TestDates.date(2026, 5, 20, 18, 0),
                status: .taken
            )
        ]

        await viewModel.retry()

        #expect(repository.fetchedRangeRequests.count == 2)
        #expect(viewModel.doses.count == 1)
        #expect(viewModel.errorMessage == nil)
    }

    private func makeViewModel(
        repository: MockScheduledDoseRepository,
        referenceDate: Date = TestDates.date(2026, 5, 30, 14, 30)
    ) -> HistoryViewModel {
        HistoryViewModel(
            reviewMedicationHistoryUseCase: ReviewMedicationHistoryUseCase(
                scheduledDoseRepository: repository,
                calendar: TestDates.calendar
            ),
            calendar: TestDates.calendar,
            referenceDateProvider: { referenceDate }
        )
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}
