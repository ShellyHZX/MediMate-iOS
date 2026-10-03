import Foundation
import Testing
@testable import MediMate

@MainActor
struct MedicationListViewModelTests {
    @Test func initialStateIsEmptyAndNotLoading() {
        let viewModel = makeListViewModel(repository: MockMedicationRepository())

        #expect(viewModel.medications.isEmpty)
        #expect(viewModel.activeMedications.isEmpty)
        #expect(viewModel.inactiveMedications.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func successfulLoadPublishesMedications() async throws {
        let repository = MockMedicationRepository()
        let medications = [
            try makeMedication(id: uuid("00000000-0000-0000-0000-000000005001"), name: "A"),
            try makeMedication(id: uuid("00000000-0000-0000-0000-000000005002"), name: "B", isActive: false)
        ]
        repository.medications = medications
        let viewModel = makeListViewModel(repository: repository)

        await viewModel.loadMedications()

        #expect(viewModel.medications == medications)
        #expect(repository.fetchedAllMedicationsCount == 1)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func activeAndInactiveGroupsPreserveLoadedOrdering() async throws {
        let repository = MockMedicationRepository()
        let inactiveFirst = try makeMedication(id: uuid("00000000-0000-0000-0000-000000005003"), name: "Inactive First", isActive: false)
        let activeFirst = try makeMedication(id: uuid("00000000-0000-0000-0000-000000005004"), name: "Active First")
        let activeSecond = try makeMedication(id: uuid("00000000-0000-0000-0000-000000005005"), name: "Active Second")
        let inactiveSecond = try makeMedication(id: uuid("00000000-0000-0000-0000-000000005006"), name: "Inactive Second", isActive: false)
        repository.medications = [inactiveFirst, activeFirst, activeSecond, inactiveSecond]
        let viewModel = makeListViewModel(repository: repository)

        await viewModel.loadMedications()

        #expect(viewModel.activeMedications == [activeFirst, activeSecond])
        #expect(viewModel.inactiveMedications == [inactiveFirst, inactiveSecond])
    }

    @Test func loadFailurePublishesHumanFacingErrorAndClearsLoading() async {
        let repository = MockMedicationRepository()
        repository.fetchAllMedicationsError = MockMedicationRepositoryError.requestedFailure
        let viewModel = makeListViewModel(repository: repository)

        await viewModel.loadMedications()

        #expect(viewModel.errorMessage == "We couldn't load your medications. Please try again.")
        #expect(!viewModel.isLoading)
    }
}

@MainActor
struct MedicationFormViewModelAddTests {
    @Test func addModeInitialStateIsEmptyWithDeterministicDefaults() {
        let viewModel = makeAddFormViewModel(repository: MockMedicationRepository())

        #expect(viewModel.isAddMode)
        #expect(!viewModel.isEditMode)
        #expect(!viewModel.isDeactivationAvailable)
        #expect(viewModel.name.isEmpty)
        #expect(viewModel.dosageAmountText.isEmpty)
        #expect(viewModel.dosageUnit == .mg)
        #expect(viewModel.instructions.isEmpty)
        #expect(viewModel.dailyDoseTimes.isEmpty)
        #expect(!viewModel.isSaving)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func validAddFormSavesThroughAddAndScheduleUseCase() async throws {
        let repository = MockMedicationRepository()
        let scheduledDoseRepository = MockScheduledDoseRepository()
        let medicationID = uuid("00000000-0000-0000-0000-000000005101")
        let createdAt = TestDates.date(2026, 3, 1, 9, 0)
        let viewModel = makeAddFormViewModel(
            repository: repository,
            scheduledDoseRepository: scheduledDoseRepository,
            uuidFactory: { medicationID },
            dateFactory: { createdAt }
        )
        viewModel.name = "Vitamin D"
        viewModel.dosageAmountText = "2"
        viewModel.dosageUnit = .tablet
        viewModel.instructions = "Take with breakfast"
        viewModel.dailyDoseTimes = [try doseTime(8, 0)]

        let medication = try #require(await viewModel.save())

        #expect(medication.id == medicationID)
        #expect(medication.createdAt == createdAt)
        #expect(medication.name == "Vitamin D")
        #expect(repository.savedMedications == [medication])
        #expect(scheduledDoseRepository.batchSavedScheduledDoses.first?.allSatisfy { $0.medicationID == medicationID } == true)
        #expect(viewModel.savedMedication == medication)
        #expect(!viewModel.isSaving)
    }

    @Test func invalidDosageTextShowsPresentationErrorWithoutSaving() async {
        let repository = MockMedicationRepository()
        let viewModel = makeAddFormViewModel(repository: repository)
        viewModel.name = "Vitamin D"
        viewModel.dosageAmountText = "abc"

        let medication = await viewModel.save()

        #expect(medication == nil)
        #expect(viewModel.errorMessage == "Enter a dosage greater than zero.")
        #expect(repository.savedMedications.isEmpty)
        #expect(!viewModel.isSaving)
    }

    @Test func blankNameUseCaseErrorMapsToUsefulText() async throws {
        let repository = MockMedicationRepository()
        let viewModel = try makeValidAddFormViewModel(repository: repository)
        viewModel.name = " \n "

        let medication = await viewModel.save()

        #expect(medication == nil)
        #expect(viewModel.errorMessage == "Enter a medication name.")
        #expect(repository.savedMedications.isEmpty)
    }

    @Test func duplicateDoseTimeUseCaseErrorMapsToUsefulText() async throws {
        let repository = MockMedicationRepository()
        let viewModel = try makeValidAddFormViewModel(repository: repository)
        let morningDose = try doseTime(8, 0)
        viewModel.dailyDoseTimes = [morningDose, morningDose]

        let medication = await viewModel.save()

        #expect(medication == nil)
        #expect(viewModel.errorMessage == "That dose time is already in the schedule.")
        #expect(repository.savedMedications.isEmpty)
    }

    @Test func isSavingReturnsToFalseAfterSaveFailure() async throws {
        let repository = MockMedicationRepository()
        repository.saveMedicationError = MockMedicationRepositoryError.requestedFailure
        let viewModel = try makeValidAddFormViewModel(repository: repository)

        let medication = await viewModel.save()

        #expect(medication == nil)
        #expect(viewModel.errorMessage == "We couldn't save this medication. Please try again.")
        #expect(!viewModel.isSaving)
    }

    @Test func schedulingFailureShowsPartialFailureMessage() async throws {
        let repository = MockMedicationRepository()
        let scheduledDoseRepository = MockScheduledDoseRepository()
        scheduledDoseRepository.saveScheduledDosesError = MockScheduledDoseRepositoryError.requestedFailure
        let viewModel = try makeValidAddFormViewModel(
            repository: repository,
            scheduledDoseRepository: scheduledDoseRepository
        )

        let medication = await viewModel.save()

        #expect(medication == nil)
        #expect(repository.savedMedications.count == 1)
        #expect(viewModel.errorMessage == "The medication was saved, but its upcoming doses couldn't be prepared. Please try again.")
        #expect(!viewModel.isSaving)
    }
}

@MainActor
struct MedicationFormViewModelEditTests {
    @Test func editModePrepopulatesFieldsFromExistingMedication() async throws {
        let repository = MockMedicationRepository()
        let existingMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000005201"),
            name: "Medication A",
            dosage: Dosage(amount: 500, unit: .mg),
            instructions: "Take nightly",
            doseTimes: [(8, 0), (20, 0)]
        )
        let viewModel = makeEditFormViewModel(repository: repository, medication: existingMedication)

        #expect(viewModel.isEditMode)
        #expect(viewModel.isDeactivationAvailable)
        #expect(viewModel.name == "Medication A")
        #expect(viewModel.dosageAmountText == "500")
        #expect(viewModel.dosageUnit == .mg)
        #expect(viewModel.instructions == "Take nightly")
        #expect(viewModel.dailyDoseTimes == existingMedication.schedule.dailyDoseTimes)
    }

    @Test func editSaveInvokesUpdateSemanticsAndPreservesIdentity() async throws {
        let repository = MockMedicationRepository()
        let existingMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000005202"),
            name: "Medication A",
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )
        repository.medicationByID[existingMedication.id] = existingMedication
        let viewModel = makeEditFormViewModel(repository: repository, medication: existingMedication)
        viewModel.name = "Medication B"
        viewModel.dosageAmountText = "2"
        viewModel.dosageUnit = .capsule
        viewModel.dailyDoseTimes = [try doseTime(12, 0)]

        let medication = try #require(await viewModel.save())

        #expect(medication.id == existingMedication.id)
        #expect(medication.createdAt == existingMedication.createdAt)
        #expect(repository.fetchedMedicationIDs == [existingMedication.id])
        #expect(repository.savedMedications == [medication])
    }

    @Test func editResultContainsChangedValues() async throws {
        let repository = MockMedicationRepository()
        let existingMedication = try makeMedication(id: uuid("00000000-0000-0000-0000-000000005203"))
        repository.medicationByID[existingMedication.id] = existingMedication
        let viewModel = makeEditFormViewModel(repository: repository, medication: existingMedication)
        viewModel.name = " Updated "
        viewModel.dosageAmountText = "750"
        viewModel.dosageUnit = .mg
        viewModel.instructions = " With water "
        viewModel.dailyDoseTimes = [try doseTime(21, 30)]

        let medication = try #require(await viewModel.save())
        let expectedDosage = try #require(Dosage(amount: 750, unit: .mg))
        let expectedDoseTime = try doseTime(21, 30)

        #expect(medication.name == "Updated")
        #expect(medication.dosage == expectedDosage)
        #expect(medication.instructions == "With water")
        #expect(medication.schedule.dailyDoseTimes == [expectedDoseTime])
        #expect(viewModel.savedMedication == medication)
    }

    @Test func updateFailureMapsToUsefulError() async throws {
        let repository = MockMedicationRepository()
        let existingMedication = try makeMedication(id: uuid("00000000-0000-0000-0000-000000005204"))
        repository.medicationByID[existingMedication.id] = existingMedication
        repository.saveMedicationError = MockMedicationRepositoryError.requestedFailure
        let viewModel = makeEditFormViewModel(repository: repository, medication: existingMedication)
        viewModel.dosageAmountText = "1"

        let medication = await viewModel.save()

        #expect(medication == nil)
        #expect(viewModel.errorMessage == "We couldn't save this medication. Please try again.")
        #expect(!viewModel.isSaving)
    }
}

@MainActor
struct MedicationFormViewModelDoseTimeEditingTests {
    @Test func addingTimeUpdatesPresentationStateChronologically() async throws {
        let viewModel = makeAddFormViewModel(repository: MockMedicationRepository())
        let eveningDose = try doseTime(20, 0)
        let morningDose = try doseTime(8, 0)

        viewModel.addDoseTime(eveningDose)
        viewModel.addDoseTime(morningDose)

        #expect(viewModel.dailyDoseTimes == [morningDose, eveningDose])
    }

    @Test func removingTimeUpdatesPresentationState() async throws {
        let viewModel = makeAddFormViewModel(repository: MockMedicationRepository())
        let morningDose = try doseTime(8, 0)
        let eveningDose = try doseTime(20, 0)
        viewModel.dailyDoseTimes = [morningDose, eveningDose]

        viewModel.removeDoseTime(at: 0)

        #expect(viewModel.dailyDoseTimes == [eveningDose])
    }

    @Test func duplicateTimeIsNotSilentlyRemovedByViewModel() async throws {
        let viewModel = makeAddFormViewModel(repository: MockMedicationRepository())
        let morningDose = try doseTime(8, 0)

        viewModel.addDoseTime(morningDose)
        viewModel.addDoseTime(morningDose)

        #expect(viewModel.dailyDoseTimes == [morningDose, morningDose])
    }
}

@MainActor
struct MedicationFormViewModelDeactivationTests {
    @Test func deactivationIsUnavailableInAddMode() async {
        let repository = MockMedicationRepository()
        let viewModel = makeAddFormViewModel(repository: repository)

        let medication = await viewModel.deactivate()

        #expect(!viewModel.isDeactivationAvailable)
        #expect(medication == nil)
        #expect(repository.savedMedications.isEmpty)
    }

    @Test func activeEditMedicationCanBeDeactivated() async throws {
        let repository = MockMedicationRepository()
        let medication = try makeMedication(id: uuid("00000000-0000-0000-0000-000000005301"), isActive: true)
        repository.medicationByID[medication.id] = medication
        let viewModel = makeEditFormViewModel(repository: repository, medication: medication)

        let deactivatedMedication = try #require(await viewModel.deactivate())

        #expect(!deactivatedMedication.isActive)
        #expect(deactivatedMedication.id == medication.id)
        #expect(repository.savedMedications == [deactivatedMedication])
        #expect(viewModel.deactivatedMedication == deactivatedMedication)
        #expect(!viewModel.isSaving)
    }

    @Test func alreadyInactiveErrorMapsMeaningfully() async throws {
        let repository = MockMedicationRepository()
        let medication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000005302"),
            isActive: false
        )
        repository.medicationByID[medication.id] = medication
        let viewModel = makeEditFormViewModel(repository: repository, medication: medication)

        let deactivatedMedication = await viewModel.deactivate()

        #expect(deactivatedMedication == nil)
        #expect(viewModel.errorMessage == "This medication is already inactive.")
        #expect(repository.savedMedications.isEmpty)
    }

    @Test func deactivationPersistenceFailureMapsMeaningfully() async throws {
        let repository = MockMedicationRepository()
        let medication = try makeMedication(id: uuid("00000000-0000-0000-0000-000000005303"))
        repository.medicationByID[medication.id] = medication
        repository.saveMedicationError = MockMedicationRepositoryError.requestedFailure
        let viewModel = makeEditFormViewModel(repository: repository, medication: medication)

        let deactivatedMedication = await viewModel.deactivate()

        #expect(deactivatedMedication == nil)
        #expect(viewModel.errorMessage == "We couldn't save this medication. Please try again.")
        #expect(!viewModel.isSaving)
    }
}

@MainActor
struct MedicationFormViewModelDeletionTests {
    @Test func deletionIsUnavailableInAddMode() async {
        let repository = MockMedicationRepository()
        let viewModel = makeAddFormViewModel(repository: repository)

        let didDelete = await viewModel.deleteMedication()

        #expect(!viewModel.isDeletionAvailable)
        #expect(!didDelete)
        #expect(repository.deletedMedicationIDs.isEmpty)
    }

    @Test func recordedHistoryDeleteFailureMapsToGuidance() async throws {
        let repository = MockMedicationRepository()
        let scheduledDoseRepository = MockScheduledDoseRepository()
        let medication = try makeMedication(id: uuid("00000000-0000-0000-0000-000000005401"))
        let takenDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-0000000054A1"),
            medicationID: medication.id,
            scheduledAt: TestDates.date(2026, 3, 1, 8, 0),
            status: .taken
        )
        repository.medicationByID[medication.id] = medication
        scheduledDoseRepository.scheduledDosesInRange = [takenDose]
        let viewModel = makeEditFormViewModel(
            repository: repository,
            medication: medication,
            scheduledDoseRepository: scheduledDoseRepository
        )

        let didDelete = await viewModel.deleteMedication()

        #expect(!didDelete)
        #expect(viewModel.errorMessage == "This medication has recorded dose history, so it can't be permanently deleted. Deactivate it instead to keep those records.")
        #expect(repository.deletedMedicationIDs.isEmpty)
        #expect(scheduledDoseRepository.deletedScheduledDoseIDs.isEmpty)
        #expect(!viewModel.isSaving)
    }

    @Test func editMedicationWithoutHistoryCanBeDeleted() async throws {
        let repository = MockMedicationRepository()
        let scheduledDoseRepository = MockScheduledDoseRepository()
        let medication = try makeMedication(id: uuid("00000000-0000-0000-0000-000000005402"))
        let upcomingDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-0000000054B1"),
            medicationID: medication.id,
            scheduledAt: TestDates.date(2026, 3, 1, 8, 0),
            status: .upcoming
        )
        repository.medicationByID[medication.id] = medication
        scheduledDoseRepository.scheduledDosesInRange = [upcomingDose]
        let viewModel = makeEditFormViewModel(
            repository: repository,
            medication: medication,
            scheduledDoseRepository: scheduledDoseRepository
        )

        let didDelete = await viewModel.deleteMedication()

        #expect(didDelete)
        #expect(viewModel.didDeleteMedication)
        #expect(repository.deletedMedicationIDs == [medication.id])
        #expect(scheduledDoseRepository.deletedScheduledDoseIDs == [[upcomingDose.id]])
        #expect(!viewModel.isSaving)
    }
}

@MainActor
private func makeListViewModel(repository: MockMedicationRepository) -> MedicationListViewModel {
    MedicationListViewModel(
        reviewMedicationsUseCase: ReviewMedicationsUseCase(medicationRepository: repository)
    )
}

@MainActor
private func makeAddFormViewModel(
    repository: MockMedicationRepository,
    scheduledDoseRepository: MockScheduledDoseRepository = MockScheduledDoseRepository(),
    uuidFactory: @escaping () -> UUID = { uuid("00000000-0000-0000-0000-000000005999") },
    dateFactory: @escaping () -> Date = { TestDates.date(2026, 3, 1, 9, 0) },
    referenceDateProvider: @escaping () -> Date = { TestDates.date(2026, 3, 1, 12, 0) }
) -> MedicationFormViewModel {
    let addMedicationUseCase = AddMedicationUseCase(
        medicationRepository: repository,
        uuidFactory: uuidFactory,
        dateFactory: dateFactory
    )
    let scheduleMedicationUseCase = ScheduleMedicationUseCase(
        scheduledDoseRepository: scheduledDoseRepository,
        calendar: TestDates.calendar
    )

    return MedicationFormViewModel(
        mode: .add,
        addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase(
            addMedicationUseCase: addMedicationUseCase,
            scheduleMedicationUseCase: scheduleMedicationUseCase,
            calendar: TestDates.calendar,
            referenceDateProvider: referenceDateProvider
        ),
        updateMedicationAndRescheduleUseCase: UpdateMedicationAndRescheduleUseCase(
            updateMedicationUseCase: UpdateMedicationUseCase(medicationRepository: repository),
            scheduleMedicationUseCase: scheduleMedicationUseCase,
            scheduledDoseRepository: scheduledDoseRepository,
            calendar: TestDates.calendar,
            referenceDateProvider: referenceDateProvider
        ),
        deactivateMedicationUseCase: DeactivateMedicationUseCase(medicationRepository: repository),
        deleteMedicationUseCase: DeleteMedicationUseCase(
            medicationRepository: repository,
            scheduledDoseRepository: scheduledDoseRepository
        )
    )
}

@MainActor
private func makeValidAddFormViewModel(
    repository: MockMedicationRepository,
    scheduledDoseRepository: MockScheduledDoseRepository = MockScheduledDoseRepository()
) throws -> MedicationFormViewModel {
    let viewModel = makeAddFormViewModel(
        repository: repository,
        scheduledDoseRepository: scheduledDoseRepository
    )
    viewModel.name = "Vitamin D"
    viewModel.dosageAmountText = "1"
    viewModel.dosageUnit = .tablet
    viewModel.dailyDoseTimes = [try doseTime(8, 0)]
    return viewModel
}

@MainActor
private func makeEditFormViewModel(
    repository: MockMedicationRepository,
    medication: Medication,
    scheduledDoseRepository: MockScheduledDoseRepository = MockScheduledDoseRepository()
) -> MedicationFormViewModel {
    let addMedicationUseCase = AddMedicationUseCase(medicationRepository: repository)
    let scheduleMedicationUseCase = ScheduleMedicationUseCase(
        scheduledDoseRepository: scheduledDoseRepository,
        calendar: TestDates.calendar
    )

    return MedicationFormViewModel(
        mode: .edit(medication),
        addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase(
            addMedicationUseCase: addMedicationUseCase,
            scheduleMedicationUseCase: scheduleMedicationUseCase,
            calendar: TestDates.calendar
        ),
        updateMedicationAndRescheduleUseCase: UpdateMedicationAndRescheduleUseCase(
            updateMedicationUseCase: UpdateMedicationUseCase(medicationRepository: repository),
            scheduleMedicationUseCase: scheduleMedicationUseCase,
            scheduledDoseRepository: scheduledDoseRepository,
            calendar: TestDates.calendar,
            referenceDateProvider: { TestDates.date(2026, 3, 1, 12, 0) }
        ),
        deactivateMedicationUseCase: DeactivateMedicationUseCase(medicationRepository: repository),
        deleteMedicationUseCase: DeleteMedicationUseCase(
            medicationRepository: repository,
            scheduledDoseRepository: scheduledDoseRepository
        )
    )
}

private func makeMedication(
    id: UUID,
    name: String = "Vitamin D",
    dosage: Dosage? = Dosage(amount: 1, unit: .tablet),
    instructions: String? = nil,
    doseTimes: [(hour: Int, minute: Int)] = [(8, 0)],
    isActive: Bool = true,
    createdAt: Date = TestDates.date(2026, 1, 1, 9, 0)
) throws -> Medication {
    let dailyDoseTimes = try doseTimes.map { try doseTime($0.hour, $0.minute) }
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

private func doseTime(_ hour: Int, _ minute: Int) throws -> DoseTime {
    try #require(DoseTime(hour: hour, minute: minute))
}

private func uuid(_ value: String) -> UUID {
    UUID(uuidString: value)!
}
