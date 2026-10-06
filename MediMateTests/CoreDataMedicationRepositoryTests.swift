import CoreData
import Foundation
import Testing
@testable import MediMate

@MainActor
@Suite(.serialized)
struct CoreDataMedicationRepositoryTests {
    @Test func saveAndFetchByIDRoundTripsMedication() async throws {
        let environment = makeEnvironment()
        let medication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000001001"),
            name: "Vitamin D",
            dosage: Dosage(amount: 2, unit: .tablet),
            instructions: "Take with breakfast",
            doseTimes: [(8, 0), (20, 30)],
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )

        try await environment.repository.saveMedication(medication)
        let fetchedMedication = try await environment.repository.fetchMedication(id: medication.id)

        #expect(fetchedMedication == medication)
    }

    @Test func savingSameMedicationIDUpdatesExistingMedicationAndReplacesDoseTimes() async throws {
        let environment = makeEnvironment()
        let medicationID = uuid("00000000-0000-0000-0000-000000001002")
        let originalMedication = try makeMedication(
            id: medicationID,
            name: "Medication A",
            dosage: Dosage(amount: 500, unit: .mg),
            instructions: "Original instructions",
            doseTimes: [(8, 0), (18, 0)],
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )
        let updatedMedication = try makeMedication(
            id: medicationID,
            name: "Medication A Updated",
            dosage: Dosage(amount: 1000, unit: .mg),
            instructions: "Updated instructions",
            doseTimes: [(12, 15)],
            createdAt: originalMedication.createdAt
        )

        try await environment.repository.saveMedication(originalMedication)
        try await environment.repository.saveMedication(updatedMedication)

        let fetchedMedication = try await environment.repository.fetchMedication(id: medicationID)
        let allMedications = try await environment.repository.fetchAllMedications()
        let matchingMedications = allMedications.filter { $0.id == medicationID }

        #expect(fetchedMedication == updatedMedication)
        #expect(matchingMedications.count == 1)
        #expect(fetchedMedication?.schedule.dailyDoseTimes == updatedMedication.schedule.dailyDoseTimes)
    }

    @Test func doseTimeRelationshipRoundTripsWithoutDuplicatesInChronologicalOrder() async throws {
        let environment = makeEnvironment()
        let medication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000001003"),
            name: "Chronology Check",
            dosage: Dosage(amount: 1, unit: .capsule),
            instructions: nil,
            doseTimes: [(21, 0), (7, 30), (13, 15)],
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )

        try await environment.repository.saveMedication(medication)
        let fetchedMedication = try #require(try await environment.repository.fetchMedication(id: medication.id))
        let fetchedDoseTimes = fetchedMedication.schedule.dailyDoseTimes

        #expect(fetchedDoseTimes == [
            try #require(DoseTime(hour: 7, minute: 30)),
            try #require(DoseTime(hour: 13, minute: 15)),
            try #require(DoseTime(hour: 21, minute: 0))
        ])
        #expect(Set(fetchedDoseTimes).count == fetchedDoseTimes.count)
    }

    @Test func fetchAllIncludesInactiveMedications() async throws {
        let environment = makeEnvironment()
        let activeMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000001004"),
            name: "Active Medication",
            dosage: Dosage(amount: 1, unit: .tablet),
            instructions: nil,
            doseTimes: [(8, 0)],
            isActive: true,
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )
        let inactiveMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000001005"),
            name: "Inactive Medication",
            dosage: Dosage(amount: 1, unit: .tablet),
            instructions: nil,
            doseTimes: [(9, 0)],
            isActive: false,
            createdAt: TestDates.date(2026, 1, 2, 9, 0)
        )

        try await environment.repository.saveMedication(activeMedication)
        try await environment.repository.saveMedication(inactiveMedication)

        let fetchedMedications = try await environment.repository.fetchAllMedications()

        #expect(fetchedMedications.contains(activeMedication))
        #expect(fetchedMedications.contains(inactiveMedication))
    }

    @Test func fetchAllReturnsMedicationsByCreatedAtThenName() async throws {
        let environment = makeEnvironment()
        let laterMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000001006"),
            name: "Later",
            dosage: Dosage(amount: 1, unit: .tablet),
            instructions: nil,
            doseTimes: [(10, 0)],
            createdAt: TestDates.date(2026, 1, 3, 9, 0)
        )
        let alphaMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000001007"),
            name: "Alpha",
            dosage: Dosage(amount: 1, unit: .tablet),
            instructions: nil,
            doseTimes: [(8, 0)],
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )
        let betaMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000001008"),
            name: "Beta",
            dosage: Dosage(amount: 1, unit: .tablet),
            instructions: nil,
            doseTimes: [(9, 0)],
            createdAt: alphaMedication.createdAt
        )

        try await environment.repository.saveMedication(laterMedication)
        try await environment.repository.saveMedication(betaMedication)
        try await environment.repository.saveMedication(alphaMedication)

        let fetchedMedications = try await environment.repository.fetchAllMedications()

        #expect(fetchedMedications.map(\.id) == [
            alphaMedication.id,
            betaMedication.id,
            laterMedication.id
        ])
    }

    @Test func deleteMedicationRemovesMedicationAndIgnoresUnknownID() async throws {
        let environment = makeEnvironment()
        let deletedMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000001009"),
            name: "Delete Me",
            dosage: Dosage(amount: 1, unit: .tablet),
            instructions: nil,
            doseTimes: [(8, 0)],
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )
        let keptMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000001010"),
            name: "Keep Me",
            dosage: Dosage(amount: 1, unit: .tablet),
            instructions: nil,
            doseTimes: [(9, 0)],
            createdAt: TestDates.date(2026, 1, 2, 9, 0)
        )

        try await environment.repository.saveMedication(deletedMedication)
        try await environment.repository.saveMedication(keptMedication)
        try await environment.repository.deleteMedication(id: deletedMedication.id)
        try await environment.repository.deleteMedication(id: uuid("00000000-0000-0000-0000-000000001099"))

        let deletedFetchResult = try await environment.repository.fetchMedication(id: deletedMedication.id)
        let keptFetchResult = try await environment.repository.fetchMedication(id: keptMedication.id)

        #expect(deletedFetchResult == nil)
        #expect(keptFetchResult == keptMedication)
    }

    private func makeEnvironment() -> CoreDataMedicationRepositoryTestEnvironment {
        let persistenceController = PersistenceController(inMemory: true)
        return CoreDataMedicationRepositoryTestEnvironment(
            persistenceController: persistenceController,
            repository: CoreDataMedicationRepository(context: persistenceController.viewContext)
        )
    }

    private func makeMedication(
        id: UUID,
        name: String,
        dosage: Dosage?,
        instructions: String?,
        doseTimes: [(hour: Int, minute: Int)],
        isActive: Bool = true,
        createdAt: Date
    ) throws -> Medication {
        let dailyDoseTimes = try doseTimes.map { try #require(DoseTime(hour: $0.hour, minute: $0.minute)) }
        let schedule = try #require(DoseSchedule(dailyDoseTimes: dailyDoseTimes))

        return Medication(
            id: id,
            name: name,
            dosage: try #require(dosage),
            instructions: instructions,
            schedule: schedule,
            isActive: isActive,
            createdAt: createdAt
        )
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}

private struct CoreDataMedicationRepositoryTestEnvironment {
    let persistenceController: PersistenceController
    let repository: CoreDataMedicationRepository
}
