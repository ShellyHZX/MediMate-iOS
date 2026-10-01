import CoreData
import Foundation
import Testing
@testable import MediMate

struct CoreDataScheduledDoseRepositoryTests {
    @Test func saveAndFetchByIDRoundTripsScheduledDoseWithoutMedicationEntity() async throws {
        let environment = makeEnvironment()
        let scheduledDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000002001"),
            medicationID: uuid("00000000-0000-0000-0000-000000003001"),
            medicationName: "Vitamin D",
            dosage: Dosage(amount: 1, unit: .tablet),
            scheduledAt: TestDates.date(2026, 1, 10, 8, 0),
            status: .taken,
            takenAt: TestDates.date(2026, 1, 10, 8, 10)
        )

        try await environment.scheduledDoseRepository.saveScheduledDose(scheduledDose)
        let fetchedDose = try await environment.scheduledDoseRepository.fetchScheduledDose(id: scheduledDose.id)

        #expect(fetchedDose == scheduledDose)
    }

    @Test func batchSaveAndDateRangeFetchReturnsOnlyMatchingDosesChronologically() async throws {
        let environment = makeEnvironment()
        let beforeRange = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000002002"),
            scheduledAt: TestDates.date(2026, 1, 10, 7, 59),
            status: .upcoming
        )
        let morningDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000002003"),
            scheduledAt: TestDates.date(2026, 1, 10, 8, 0),
            status: .due
        )
        let eveningDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000002004"),
            scheduledAt: TestDates.date(2026, 1, 10, 18, 0),
            status: .upcoming
        )
        let afterRange = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000002005"),
            scheduledAt: TestDates.date(2026, 1, 11, 0, 0),
            status: .upcoming
        )

        try await environment.scheduledDoseRepository.saveScheduledDoses([
            eveningDose,
            afterRange,
            beforeRange,
            morningDose
        ])

        let fetchedDoses = try await environment.scheduledDoseRepository.fetchScheduledDoses(
            from: TestDates.date(2026, 1, 10, 8, 0),
            to: TestDates.date(2026, 1, 11, 0, 0)
        )

        #expect(fetchedDoses == [morningDose, eveningDose])
    }

    @Test func dateRangeFetchUsesHalfOpenBoundary() async throws {
        let environment = makeEnvironment()
        let startDate = TestDates.date(2026, 1, 10, 8, 0)
        let endDate = TestDates.date(2026, 1, 10, 18, 0)
        let startBoundaryDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000002006"),
            scheduledAt: startDate,
            status: .upcoming
        )
        let insideDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000002007"),
            scheduledAt: TestDates.date(2026, 1, 10, 12, 0),
            status: .upcoming
        )
        let endBoundaryDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000002008"),
            scheduledAt: endDate,
            status: .upcoming
        )

        try await environment.scheduledDoseRepository.saveScheduledDoses([
            endBoundaryDose,
            insideDose,
            startBoundaryDose
        ])

        let fetchedDoses = try await environment.scheduledDoseRepository.fetchScheduledDoses(
            from: startDate,
            to: endDate
        )

        #expect(fetchedDoses == [startBoundaryDose, insideDose])
        #expect(!fetchedDoses.contains(endBoundaryDose))
    }

    @Test func savingSameScheduledDoseIDUpdatesExistingOccurrence() async throws {
        let environment = makeEnvironment()
        let scheduledDoseID = uuid("00000000-0000-0000-0000-000000002009")
        let originalDose = try makeDose(
            id: scheduledDoseID,
            medicationName: "Original Medication",
            dosage: Dosage(amount: 1, unit: .tablet),
            scheduledAt: TestDates.date(2026, 1, 10, 8, 0),
            status: .upcoming
        )
        let updatedDose = try makeDose(
            id: scheduledDoseID,
            medicationName: "Updated Medication",
            dosage: Dosage(amount: 2, unit: .tablet),
            scheduledAt: TestDates.date(2026, 1, 10, 9, 0),
            status: .taken,
            takenAt: TestDates.date(2026, 1, 10, 9, 5)
        )

        try await environment.scheduledDoseRepository.saveScheduledDose(originalDose)
        try await environment.scheduledDoseRepository.saveScheduledDose(updatedDose)

        let fetchedDose = try await environment.scheduledDoseRepository.fetchScheduledDose(id: scheduledDoseID)
        let fetchedDoses = try await environment.scheduledDoseRepository.fetchScheduledDoses(
            from: TestDates.date(2026, 1, 10, 0, 0),
            to: TestDates.date(2026, 1, 11, 0, 0)
        )

        #expect(fetchedDose == updatedDose)
        #expect(fetchedDoses.filter { $0.id == scheduledDoseID } == [updatedDose])
    }

    @Test func missingMedicationRelationshipPreservesScheduledDoseSnapshot() async throws {
        let environment = makeEnvironment()
        let medicationID = uuid("00000000-0000-0000-0000-000000003005")
        let scheduledDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000002010"),
            medicationID: medicationID,
            medicationName: "Historical Medication",
            dosage: Dosage(amount: 500, unit: .mg),
            scheduledAt: TestDates.date(2026, 1, 10, 8, 0),
            status: .upcoming
        )

        try await environment.scheduledDoseRepository.saveScheduledDose(scheduledDose)
        let fetchedDose = try await environment.scheduledDoseRepository.fetchScheduledDose(id: scheduledDose.id)
        let hasMissingMedicationRelationship = try await hasNilMedicationRelationship(
            scheduledDoseID: scheduledDose.id,
            context: environment.context
        )

        #expect(fetchedDose == scheduledDose)
        #expect(fetchedDose?.medicationID == medicationID)
        #expect(fetchedDose?.medicationName == "Historical Medication")
        #expect(fetchedDose?.dosage == scheduledDose.dosage)
        #expect(hasMissingMedicationRelationship)
    }

    @Test func existingMedicationRelationshipPointsToMatchingMedicationEntity() async throws {
        let environment = makeEnvironment()
        let medication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000003006"),
            name: "Related Medication",
            dosage: Dosage(amount: 1, unit: .capsule),
            doseTimes: [(8, 0)],
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )
        let scheduledDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000002011"),
            medicationID: medication.id,
            medicationName: medication.name,
            dosage: medication.dosage,
            scheduledAt: TestDates.date(2026, 1, 10, 8, 0),
            status: .upcoming
        )

        try await environment.medicationRepository.saveMedication(medication)
        try await environment.scheduledDoseRepository.saveScheduledDose(scheduledDose)

        let fetchedDose = try await environment.scheduledDoseRepository.fetchScheduledDose(id: scheduledDose.id)
        let relatedMedicationID = try await medicationRelationshipID(
            scheduledDoseID: scheduledDose.id,
            context: environment.context
        )

        #expect(fetchedDose == scheduledDose)
        #expect(relatedMedicationID == medication.id)
    }

    @Test func scheduledDoseHistoricalSnapshotSurvivesMedicationEdit() async throws {
        let environment = makeEnvironment()
        let medicationID = uuid("00000000-0000-0000-0000-000000003007")
        let originalMedication = try makeMedication(
            id: medicationID,
            name: "Medication A",
            dosage: Dosage(amount: 500, unit: .mg),
            doseTimes: [(8, 0)],
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )
        let scheduledDose = try makeDose(
            id: uuid("00000000-0000-0000-0000-000000002012"),
            medicationID: medicationID,
            medicationName: "Medication A",
            dosage: Dosage(amount: 500, unit: .mg),
            scheduledAt: TestDates.date(2026, 1, 10, 8, 0),
            status: .upcoming
        )
        let updatedMedication = try makeMedication(
            id: medicationID,
            name: "Medication A Updated",
            dosage: Dosage(amount: 1000, unit: .mg),
            doseTimes: [(8, 0)],
            createdAt: originalMedication.createdAt
        )

        try await environment.medicationRepository.saveMedication(originalMedication)
        try await environment.scheduledDoseRepository.saveScheduledDose(scheduledDose)
        try await environment.medicationRepository.saveMedication(updatedMedication)

        let fetchedDose = try await environment.scheduledDoseRepository.fetchScheduledDose(id: scheduledDose.id)
        let expectedDosage = try #require(Dosage(amount: 500, unit: .mg))

        #expect(fetchedDose?.medicationName == "Medication A")
        #expect(fetchedDose?.dosage == expectedDosage)
        #expect(fetchedDose == scheduledDose)
    }

    @Test func savingEmptyScheduledDoseBatchSucceedsWithoutCreatingRows() async throws {
        let environment = makeEnvironment()

        try await environment.scheduledDoseRepository.saveScheduledDoses([])

        let fetchedDoses = try await environment.scheduledDoseRepository.fetchScheduledDoses(
            from: TestDates.date(2026, 1, 10, 0, 0),
            to: TestDates.date(2026, 1, 11, 0, 0)
        )

        #expect(fetchedDoses.isEmpty)
    }

    private func makeEnvironment() -> CoreDataScheduledDoseRepositoryTestEnvironment {
        let persistenceController = PersistenceController(inMemory: true)
        return CoreDataScheduledDoseRepositoryTestEnvironment(
            persistenceController: persistenceController,
            medicationRepository: CoreDataMedicationRepository(context: persistenceController.viewContext),
            scheduledDoseRepository: CoreDataScheduledDoseRepository(context: persistenceController.viewContext)
        )
    }

    private func makeMedication(
        id: UUID,
        name: String,
        dosage: Dosage?,
        doseTimes: [(hour: Int, minute: Int)],
        createdAt: Date
    ) throws -> Medication {
        let dailyDoseTimes = try doseTimes.map { try #require(DoseTime(hour: $0.hour, minute: $0.minute)) }
        let schedule = try #require(DoseSchedule(dailyDoseTimes: dailyDoseTimes))

        return Medication(
            id: id,
            name: name,
            dosage: try #require(dosage),
            schedule: schedule,
            createdAt: createdAt
        )
    }

    private func makeDose(
        id: UUID,
        medicationID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000003000")!,
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

    private func hasNilMedicationRelationship(
        scheduledDoseID: UUID,
        context: NSManagedObjectContext
    ) async throws -> Bool {
        try await context.perform {
            let request = ScheduledDoseEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", scheduledDoseID as CVarArg)
            request.fetchLimit = 1

            let scheduledDoseEntity = try context.fetch(request).first
            return scheduledDoseEntity?.medication == nil
        }
    }

    private func medicationRelationshipID(
        scheduledDoseID: UUID,
        context: NSManagedObjectContext
    ) async throws -> UUID? {
        try await context.perform {
            let request = ScheduledDoseEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", scheduledDoseID as CVarArg)
            request.fetchLimit = 1

            let scheduledDoseEntity = try context.fetch(request).first
            return scheduledDoseEntity?.medication?.id
        }
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}

private struct CoreDataScheduledDoseRepositoryTestEnvironment {
    let persistenceController: PersistenceController
    let medicationRepository: CoreDataMedicationRepository
    let scheduledDoseRepository: CoreDataScheduledDoseRepository

    var context: NSManagedObjectContext {
        persistenceController.viewContext
    }
}
