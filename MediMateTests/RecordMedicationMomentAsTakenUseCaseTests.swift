import Foundation
import Testing
@testable import MediMate

struct RecordMedicationMomentAsTakenUseCaseTests {
    @Test func batchTakenUpdatesAllRequestedUnresolvedDoses() async throws {
        let repository = MockScheduledDoseRepository()
        let dueDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000C101"),
            scheduledAt: TestDates.date(2026, 8, 1, 12, 0),
            status: .due
        )
        let upcomingDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000C102"),
            scheduledAt: TestDates.date(2026, 8, 1, 12, 0),
            status: .upcoming
        )
        repository.scheduledDoseByID[dueDose.id] = dueDose
        repository.scheduledDoseByID[upcomingDose.id] = upcomingDose
        let takenAt = TestDates.date(2026, 8, 1, 12, 5)
        let useCase = RecordMedicationMomentAsTakenUseCase(scheduledDoseRepository: repository)

        let updatedDoses = try await useCase.execute(
            scheduledDoseIDs: [dueDose.id, upcomingDose.id],
            takenAt: takenAt
        )

        #expect(updatedDoses.map(\.status) == [.taken, .taken])
        #expect(updatedDoses.allSatisfy { $0.takenAt == takenAt })
        #expect(repository.batchSavedScheduledDoses == [updatedDoses])
        #expect(repository.savedScheduledDoses.isEmpty)
    }

    @Test func emptyDoseSelectionFailsWithoutSaving() async {
        let repository = MockScheduledDoseRepository()
        let useCase = RecordMedicationMomentAsTakenUseCase(scheduledDoseRepository: repository)

        await expectThrows(RecordMedicationMomentAsTakenUseCaseError.emptyDoseSelection) {
            _ = try await useCase.execute(
                scheduledDoseIDs: [],
                takenAt: TestDates.date(2026, 8, 1, 12, 5)
            )
        }

        #expect(repository.batchSavedScheduledDoses.isEmpty)
    }

    @Test func alreadyTakenTargetFailsBeforeBatchSave() async throws {
        let repository = MockScheduledDoseRepository()
        let dueDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000C201"),
            scheduledAt: TestDates.date(2026, 8, 1, 12, 0),
            status: .due
        )
        let takenDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000C202"),
            scheduledAt: TestDates.date(2026, 8, 1, 12, 0),
            status: .taken,
            takenAt: TestDates.date(2026, 8, 1, 12, 1)
        )
        repository.scheduledDoseByID[dueDose.id] = dueDose
        repository.scheduledDoseByID[takenDose.id] = takenDose
        let useCase = RecordMedicationMomentAsTakenUseCase(scheduledDoseRepository: repository)

        await expectThrows(RecordMedicationMomentAsTakenUseCaseError.doseAlreadyTaken) {
            _ = try await useCase.execute(
                scheduledDoseIDs: [dueDose.id, takenDose.id],
                takenAt: TestDates.date(2026, 8, 1, 12, 5)
            )
        }

        #expect(repository.batchSavedScheduledDoses.isEmpty)
    }

    @Test func skippedTargetFailsBeforeBatchSave() async throws {
        let repository = MockScheduledDoseRepository()
        let skippedDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000C301"),
            scheduledAt: TestDates.date(2026, 8, 1, 12, 0),
            status: .skipped
        )
        repository.scheduledDoseByID[skippedDose.id] = skippedDose
        let useCase = RecordMedicationMomentAsTakenUseCase(scheduledDoseRepository: repository)

        await expectThrows(RecordMedicationMomentAsTakenUseCaseError.doseWasSkipped) {
            _ = try await useCase.execute(
                scheduledDoseIDs: [skippedDose.id],
                takenAt: TestDates.date(2026, 8, 1, 12, 5)
            )
        }

        #expect(repository.batchSavedScheduledDoses.isEmpty)
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}
