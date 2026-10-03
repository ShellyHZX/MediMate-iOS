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

    @Test func activityExcludesUnresolvedDueAndUpcomingDoses() async throws {
        let repository = MockScheduledDoseRepository()
        let takenDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009901"),
            scheduledAt: TestDates.date(2026, 5, 20, 8, 0),
            status: .taken
        )
        let dueDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009902"),
            scheduledAt: TestDates.date(2026, 5, 20, 9, 0),
            status: .due
        )
        let upcomingDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009903"),
            scheduledAt: TestDates.date(2026, 5, 20, 16, 0),
            status: .upcoming
        )
        repository.scheduledDosesInRange = [takenDose, dueDose, upcomingDose]
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadHistory()

        #expect(viewModel.activityDaySections.flatMap(\.moments).flatMap(\.doses).map(\.id) == [takenDose.id])
    }

    @Test func sameMinuteFinalizedDosesGroupIntoOneActivityMoment() async throws {
        let repository = MockScheduledDoseRepository()
        let firstDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009A01"),
            medicationName: "Beta",
            scheduledAt: TestDates.date(2026, 5, 20, 12, 0),
            status: .taken
        )
        let secondDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009A02"),
            medicationName: "Alpha",
            scheduledAt: TestDates.date(2026, 5, 20, 12, 0),
            status: .skipped
        )
        repository.scheduledDosesInRange = [firstDose, secondDose]
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadHistory()

        let moments = try #require(viewModel.activityDaySections.first?.moments)
        #expect(moments.count == 1)
        #expect(moments.first?.scheduledAt == TestDates.date(2026, 5, 20, 12, 0))
        #expect(moments.first?.doses.map(\.id) == [secondDose.id, firstDose.id])
    }

    @Test func differentMinutesRemainSeparateNewestFirstAndSummaryCountsStatuses() async throws {
        let repository = MockScheduledDoseRepository()
        let skippedDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009B01"),
            scheduledAt: TestDates.date(2026, 5, 20, 8, 0),
            status: .skipped
        )
        let missedDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009B02"),
            scheduledAt: TestDates.date(2026, 5, 20, 12, 0),
            status: .missed
        )
        let takenDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009B03"),
            scheduledAt: TestDates.date(2026, 5, 20, 12, 0),
            status: .taken
        )
        repository.scheduledDosesInRange = [skippedDose, missedDose, takenDose]
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadHistory()

        let moments = try #require(viewModel.activityDaySections.first?.moments)
        #expect(moments.map(\.scheduledAt) == [
            TestDates.date(2026, 5, 20, 12, 0),
            TestDates.date(2026, 5, 20, 8, 0)
        ])
        #expect(moments.first?.summary == "1 taken · 1 missed")
        #expect(moments.last?.summary == "1 skipped")
    }

    @Test func correctionToNotTakenPersistsAndReloadsActivity() async throws {
        let repository = MockScheduledDoseRepository()
        let takenDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009C01"),
            scheduledAt: TestDates.date(2026, 5, 20, 8, 0),
            status: .taken,
            takenAt: TestDates.date(2026, 5, 20, 8, 5)
        )
        repository.scheduledDoseByID[takenDose.id] = takenDose
        repository.scheduledDosesInRange = [takenDose]
        let viewModel = makeViewModel(
            repository: repository,
            referenceDate: TestDates.date(2026, 5, 20, 14, 30)
        )

        await viewModel.loadHistory()
        let record = try #require(viewModel.activityDaySections.first?.moments.first?.doses.first)
        await viewModel.markRecordAsNotTaken(record)

        #expect(repository.fetchedScheduledDoseIDs == [takenDose.id])
        #expect(repository.savedScheduledDoses.first?.status == .due)
        #expect(repository.savedScheduledDoses.first?.takenAt == nil)
        #expect(repository.fetchedRangeRequests.count == 2)
        #expect(viewModel.activityDaySections.isEmpty)
        #expect(viewModel.actionInProgressDoseID == nil)
        #expect(viewModel.correctionErrorMessage == nil)
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
            correctDoseRecordUseCase: CorrectDoseRecordUseCase(
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
