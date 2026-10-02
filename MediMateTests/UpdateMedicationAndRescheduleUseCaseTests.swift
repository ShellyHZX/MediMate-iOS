import Foundation
import Testing
@testable import MediMate

struct UpdateMedicationAndRescheduleUseCaseTests {
    private let referenceDate = TestDates.date(2026, 6, 1, 15, 0)

    @Test func editingMedicationReplacesFutureUnresolvedDoses() async throws {
        let environment = try makeEnvironment()
        let oldDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000008101"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 6, 2, 8, 0),
            status: .upcoming
        )
        environment.scheduledDoseRepository.scheduledDoseByID[oldDose.id] = oldDose
        environment.scheduledDoseRepository.scheduledDosesInRange = [oldDose]
        let input = try makeUpdateInput(
            medicationID: environment.medication.id,
            name: "Updated Vitamin D",
            doseTimes: [(9, 0)]
        )

        let result = try await environment.useCase.execute(input: input, referenceDate: referenceDate)

        #expect(environment.scheduledDoseRepository.deletedScheduledDoseIDs == [[oldDose.id]])
        #expect(!environment.scheduledDoseRepository.scheduledDosesInRange.contains { $0.id == oldDose.id })
        #expect(result.scheduledDoses.contains { $0.scheduledAt == TestDates.date(2026, 6, 2, 9, 0) })
    }

    @Test func unresolvedEarlierTodayDoseIsReplacedAfterEdit() async throws {
        let environment = try makeEnvironment()
        let earlierTodayDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000008201"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 6, 1, 12, 0),
            status: .missed
        )
        environment.scheduledDoseRepository.scheduledDoseByID[earlierTodayDose.id] = earlierTodayDose
        environment.scheduledDoseRepository.scheduledDosesInRange = [earlierTodayDose]
        let input = try makeUpdateInput(medicationID: environment.medication.id, doseTimes: [(13, 0), (18, 0)])

        let result = try await environment.useCase.execute(input: input, referenceDate: referenceDate)

        #expect(environment.scheduledDoseRepository.deletedScheduledDoseIDs == [[earlierTodayDose.id]])
        #expect(environment.scheduledDoseRepository.scheduledDoseByID[earlierTodayDose.id] == nil)
        #expect(result.scheduledDoses.contains { $0.scheduledAt == TestDates.date(2026, 6, 1, 13, 0) })
        #expect(result.scheduledDoses.contains { $0.scheduledAt == TestDates.date(2026, 6, 1, 18, 0) })
    }

    @Test func takenEarlierTodayDoseIsPreserved() async throws {
        let environment = try makeEnvironment()
        let takenDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000008202"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 6, 1, 12, 0),
            status: .taken,
            takenAt: TestDates.date(2026, 6, 1, 12, 5)
        )
        environment.scheduledDoseRepository.scheduledDoseByID[takenDose.id] = takenDose
        environment.scheduledDoseRepository.scheduledDosesInRange = [takenDose]
        let input = try makeUpdateInput(medicationID: environment.medication.id, doseTimes: [(13, 0)])

        _ = try await environment.useCase.execute(input: input, referenceDate: referenceDate)

        #expect(environment.scheduledDoseRepository.deletedScheduledDoseIDs == [[]])
        #expect(environment.scheduledDoseRepository.scheduledDoseByID[takenDose.id] == takenDose)
    }

    @Test func skippedEarlierTodayDoseIsPreserved() async throws {
        let environment = try makeEnvironment()
        let skippedDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000008203"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 6, 1, 12, 0),
            status: .skipped
        )
        environment.scheduledDoseRepository.scheduledDoseByID[skippedDose.id] = skippedDose
        environment.scheduledDoseRepository.scheduledDosesInRange = [skippedDose]
        let input = try makeUpdateInput(medicationID: environment.medication.id, doseTimes: [(13, 0)])

        _ = try await environment.useCase.execute(input: input, referenceDate: referenceDate)

        #expect(environment.scheduledDoseRepository.deletedScheduledDoseIDs == [[]])
        #expect(environment.scheduledDoseRepository.scheduledDoseByID[skippedDose.id] == skippedDose)
    }

    @Test func yesterdayScheduledDoseSnapshotsRemainUnchanged() async throws {
        let environment = try makeEnvironment()
        let yesterdayDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000008204"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 5, 31, 23, 0),
            status: .missed
        )
        environment.scheduledDoseRepository.scheduledDoseByID[yesterdayDose.id] = yesterdayDose
        environment.scheduledDoseRepository.scheduledDosesInRange = [yesterdayDose]
        let input = try makeUpdateInput(medicationID: environment.medication.id, doseTimes: [(9, 0)])

        _ = try await environment.useCase.execute(input: input, referenceDate: referenceDate)

        #expect(environment.scheduledDoseRepository.deletedScheduledDoseIDs == [[]])
        #expect(environment.scheduledDoseRepository.scheduledDoseByID[yesterdayDose.id] == yesterdayDose)
    }

    @Test func futureTakenDoseIsPreservedAndNotDuplicated() async throws {
        let environment = try makeEnvironment()
        let takenDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000008301"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 6, 2, 9, 0),
            status: .taken,
            takenAt: TestDates.date(2026, 6, 2, 9, 10)
        )
        environment.scheduledDoseRepository.scheduledDoseByID[takenDose.id] = takenDose
        environment.scheduledDoseRepository.scheduledDosesInRange = [takenDose]
        let input = try makeUpdateInput(medicationID: environment.medication.id, doseTimes: [(9, 0)])

        let result = try await environment.useCase.execute(input: input, referenceDate: referenceDate)

        let matchingDoses = environment.scheduledDoseRepository.scheduledDosesInRange.filter {
            $0.scheduledAt == takenDose.scheduledAt && $0.medicationID == environment.medication.id
        }
        #expect(environment.scheduledDoseRepository.deletedScheduledDoseIDs == [[]])
        #expect(matchingDoses == [takenDose])
        #expect(!result.scheduledDoses.contains { $0.scheduledAt == takenDose.scheduledAt })
    }

    @Test func futureSkippedDoseIsPreservedAndNotDeleted() async throws {
        let environment = try makeEnvironment()
        let skippedDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000008401"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 6, 2, 11, 0),
            status: .skipped
        )
        environment.scheduledDoseRepository.scheduledDoseByID[skippedDose.id] = skippedDose
        environment.scheduledDoseRepository.scheduledDosesInRange = [skippedDose]
        let input = try makeUpdateInput(medicationID: environment.medication.id, doseTimes: [(11, 0)])

        _ = try await environment.useCase.execute(input: input, referenceDate: referenceDate)

        #expect(environment.scheduledDoseRepository.deletedScheduledDoseIDs == [[]])
        #expect(environment.scheduledDoseRepository.scheduledDoseByID[skippedDose.id] == skippedDose)
    }

    @Test func updatedNameAndDosageAppearInNewFutureSnapshots() async throws {
        let environment = try makeEnvironment()
        let input = try makeUpdateInput(
            medicationID: environment.medication.id,
            name: "Updated Medication",
            dosageAmount: 2,
            dosageUnit: .capsule,
            doseTimes: [(18, 0)]
        )

        let result = try await environment.useCase.execute(input: input, referenceDate: referenceDate)
        let generatedDose = try #require(result.scheduledDoses.first)
        let expectedDosage = try #require(Dosage(amount: 2, unit: .capsule))

        #expect(generatedDose.medicationName == "Updated Medication")
        #expect(generatedDose.dosage == expectedDosage)
    }

    @Test func updatedDoseTimesReplaceOldFutureSchedule() async throws {
        let environment = try makeEnvironment()
        let oldDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000008501"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 6, 2, 8, 0),
            status: .due
        )
        environment.scheduledDoseRepository.scheduledDoseByID[oldDose.id] = oldDose
        environment.scheduledDoseRepository.scheduledDosesInRange = [oldDose]
        let input = try makeUpdateInput(medicationID: environment.medication.id, doseTimes: [(10, 30)])

        let result = try await environment.useCase.execute(input: input, referenceDate: referenceDate)

        #expect(environment.scheduledDoseRepository.deletedScheduledDoseIDs == [[oldDose.id]])
        #expect(!result.scheduledDoses.contains { TestDates.calendar.component(.hour, from: $0.scheduledAt) == 8 })
        #expect(result.scheduledDoses.contains { $0.scheduledAt == TestDates.date(2026, 6, 2, 10, 30) })
    }

    @Test func unrelatedMedicationDosesAreUntouched() async throws {
        let environment = try makeEnvironment()
        let unrelatedDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000008601"),
            medicationID: uuid("00000000-0000-0000-0000-0000000086FF"),
            scheduledAt: TestDates.date(2026, 6, 2, 8, 0),
            status: .upcoming
        )
        environment.scheduledDoseRepository.scheduledDoseByID[unrelatedDose.id] = unrelatedDose
        environment.scheduledDoseRepository.scheduledDosesInRange = [unrelatedDose]
        let input = try makeUpdateInput(medicationID: environment.medication.id, doseTimes: [(9, 0)])

        _ = try await environment.useCase.execute(input: input, referenceDate: referenceDate)

        #expect(environment.scheduledDoseRepository.deletedScheduledDoseIDs == [[]])
        #expect(environment.scheduledDoseRepository.scheduledDoseByID[unrelatedDose.id] == unrelatedDose)
    }

    @Test func reschedulingDeleteFailureReturnsTypedPartialFailureAfterMedicationUpdate() async throws {
        let environment = try makeEnvironment()
        let oldDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000008701"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 6, 2, 8, 0),
            status: .upcoming
        )
        environment.scheduledDoseRepository.scheduledDoseByID[oldDose.id] = oldDose
        environment.scheduledDoseRepository.scheduledDosesInRange = [oldDose]
        environment.scheduledDoseRepository.deleteScheduledDosesError = MockScheduledDoseRepositoryError.requestedFailure
        let input = try makeUpdateInput(medicationID: environment.medication.id, name: "Saved Name", doseTimes: [(9, 0)])

        await expectThrows(UpdateMedicationAndRescheduleUseCaseError.deleteScheduledDosesFailure) {
            _ = try await environment.useCase.execute(input: input, referenceDate: referenceDate)
        }

        #expect(environment.medicationRepository.savedMedications.last?.name == "Saved Name")
        #expect(environment.scheduledDoseRepository.batchSavedScheduledDoses.isEmpty)
    }

    @Test func deterministicReferenceDateDrivesFetchAndHorizonRange() async throws {
        let environment = try makeEnvironment()
        let input = try makeUpdateInput(medicationID: environment.medication.id, doseTimes: [(9, 0)])

        _ = try await environment.useCase.execute(input: input, referenceDate: referenceDate)

        let requestedRange = try #require(environment.scheduledDoseRepository.fetchedRangeRequests.first)
        let expectedEndDate = try #require(TestDates.calendar.date(
            byAdding: .day,
            value: 14,
            to: TestDates.calendar.startOfDay(for: referenceDate)
        ))

        #expect(requestedRange.startDate == TestDates.calendar.startOfDay(for: referenceDate))
        #expect(requestedRange.endDate == expectedEndDate)
    }

    @Test func regeneratedEarlierTodayOccurrenceCanLaterBeClassifiedAsDue() async throws {
        let environment = try makeEnvironment()
        let input = try makeUpdateInput(medicationID: environment.medication.id, doseTimes: [(13, 0)])

        let result = try await environment.useCase.execute(input: input, referenceDate: referenceDate)
        let earlierTodayDose = try #require(result.scheduledDoses.first {
            $0.scheduledAt == TestDates.date(2026, 6, 1, 13, 0)
        })

        let todayRepository = MockScheduledDoseRepository()
        todayRepository.scheduledDosesInRange = [earlierTodayDose]
        let todayUseCase = ReviewTodaysMedicationUseCase(
            scheduledDoseRepository: todayRepository,
            calendar: TestDates.calendar
        )

        let summary = try await todayUseCase.execute(referenceDate: referenceDate)

        #expect(summary.doses.first?.id == earlierTodayDose.id)
        #expect(summary.doses.first?.status == .due)
    }

    @Test func finalizedEarlierTodayCollisionPreventsDuplicateGeneration() async throws {
        let environment = try makeEnvironment()
        let takenDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000008901"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 6, 1, 13, 0),
            status: .taken,
            takenAt: TestDates.date(2026, 6, 1, 13, 5)
        )
        environment.scheduledDoseRepository.scheduledDoseByID[takenDose.id] = takenDose
        environment.scheduledDoseRepository.scheduledDosesInRange = [takenDose]
        let input = try makeUpdateInput(medicationID: environment.medication.id, doseTimes: [(13, 0)])

        let result = try await environment.useCase.execute(input: input, referenceDate: referenceDate)

        let matchingDoses = environment.scheduledDoseRepository.scheduledDosesInRange.filter {
            $0.scheduledAt == takenDose.scheduledAt && $0.medicationID == environment.medication.id
        }
        #expect(matchingDoses == [takenDose])
        #expect(!result.scheduledDoses.contains { $0.scheduledAt == takenDose.scheduledAt })
    }

    private func makeEnvironment() throws -> UpdateMedicationAndRescheduleTestEnvironment {
        let medicationRepository = MockMedicationRepository()
        let scheduledDoseRepository = MockScheduledDoseRepository()
        let medication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000008000"),
            name: "Vitamin D",
            dosage: Dosage(amount: 1, unit: .tablet),
            doseTimes: [(8, 0)]
        )
        medicationRepository.medicationByID[medication.id] = medication
        let updateMedicationUseCase = UpdateMedicationUseCase(medicationRepository: medicationRepository)
        let scheduleMedicationUseCase = ScheduleMedicationUseCase(
            scheduledDoseRepository: scheduledDoseRepository,
            calendar: TestDates.calendar
        )
        let useCase = UpdateMedicationAndRescheduleUseCase(
            updateMedicationUseCase: updateMedicationUseCase,
            scheduleMedicationUseCase: scheduleMedicationUseCase,
            scheduledDoseRepository: scheduledDoseRepository,
            calendar: TestDates.calendar
        )

        return UpdateMedicationAndRescheduleTestEnvironment(
            medicationRepository: medicationRepository,
            scheduledDoseRepository: scheduledDoseRepository,
            medication: medication,
            useCase: useCase
        )
    }

    private func makeMedication(
        id: UUID,
        name: String,
        dosage: Dosage?,
        doseTimes: [(hour: Int, minute: Int)]
    ) throws -> Medication {
        let dailyDoseTimes = try doseTimes.map { try #require(DoseTime(hour: $0.hour, minute: $0.minute)) }
        let schedule = try #require(DoseSchedule(dailyDoseTimes: dailyDoseTimes))

        return Medication(
            id: id,
            name: name,
            dosage: try #require(dosage),
            schedule: schedule,
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )
    }

    private func makeDose(
        id: UUID,
        medicationID: UUID,
        medicationName: String = "Vitamin D",
        dosage: Dosage? = Dosage(amount: 1, unit: .tablet),
        scheduledAt: Date,
        status: DoseStatus,
        takenAt: Date? = nil
    ) throws -> ScheduledDose {
        ScheduledDose(
            id: id,
            medicationID: medicationID,
            medicationName: medicationName,
            dosage: try #require(dosage),
            scheduledAt: scheduledAt,
            status: status,
            takenAt: takenAt
        )
    }

    private func makeUpdateInput(
        medicationID: UUID,
        name: String = "Vitamin D Updated",
        dosageAmount: Decimal = 1,
        dosageUnit: DosageUnit = .tablet,
        doseTimes: [(hour: Int, minute: Int)]
    ) throws -> UpdateMedicationInput {
        UpdateMedicationInput(
            medicationID: medicationID,
            name: name,
            dosageAmount: dosageAmount,
            dosageUnit: dosageUnit,
            dailyDoseTimes: try doseTimes.map { try #require(DoseTime(hour: $0.hour, minute: $0.minute)) }
        )
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}

private struct UpdateMedicationAndRescheduleTestEnvironment {
    let medicationRepository: MockMedicationRepository
    let scheduledDoseRepository: MockScheduledDoseRepository
    let medication: Medication
    let useCase: UpdateMedicationAndRescheduleUseCase
}
