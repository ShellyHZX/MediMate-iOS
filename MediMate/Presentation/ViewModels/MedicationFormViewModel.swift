import Combine
import Foundation

@MainActor
final class MedicationFormViewModel: ObservableObject {
    enum Mode: Equatable {
        case add
        case edit(Medication)
    }

    @Published var name: String
    @Published var dosageAmountText: String
    @Published var dosageUnit: DosageUnit
    @Published var instructions: String
    @Published var dailyDoseTimes: [DoseTime]
    @Published private(set) var isSaving: Bool
    @Published var errorMessage: String?
    @Published private(set) var savedMedication: Medication?
    @Published private(set) var deactivatedMedication: Medication?
    @Published private(set) var didDeleteMedication: Bool

    let mode: Mode

    private let addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase
    private let updateMedicationAndRescheduleUseCase: UpdateMedicationAndRescheduleUseCase
    private let deactivateMedicationUseCase: DeactivateMedicationUseCase
    private let deleteMedicationUseCase: DeleteMedicationUseCase
    private let widgetSnapshotSynchronizer: WidgetSnapshotSynchronizing?
    private let notificationScheduler: MedicationNotificationScheduling?

    var isAddMode: Bool {
        if case .add = mode {
            return true
        }

        return false
    }

    var isEditMode: Bool {
        !isAddMode
    }

    var isDeactivationAvailable: Bool {
        isEditMode
    }

    var isDeletionAvailable: Bool {
        isEditMode
    }

    init(
        mode: Mode,
        addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase,
        updateMedicationAndRescheduleUseCase: UpdateMedicationAndRescheduleUseCase,
        deactivateMedicationUseCase: DeactivateMedicationUseCase,
        deleteMedicationUseCase: DeleteMedicationUseCase,
        widgetSnapshotSynchronizer: WidgetSnapshotSynchronizing? = nil,
        notificationScheduler: MedicationNotificationScheduling? = nil
    ) {
        self.mode = mode
        self.addMedicationAndScheduleUseCase = addMedicationAndScheduleUseCase
        self.updateMedicationAndRescheduleUseCase = updateMedicationAndRescheduleUseCase
        self.deactivateMedicationUseCase = deactivateMedicationUseCase
        self.deleteMedicationUseCase = deleteMedicationUseCase
        self.widgetSnapshotSynchronizer = widgetSnapshotSynchronizer
        self.notificationScheduler = notificationScheduler
        self.isSaving = false
        self.errorMessage = nil
        self.savedMedication = nil
        self.deactivatedMedication = nil
        self.didDeleteMedication = false

        switch mode {
        case .add:
            self.name = ""
            self.dosageAmountText = ""
            self.dosageUnit = .mg
            self.instructions = ""
            self.dailyDoseTimes = []

        case .edit(let medication):
            self.name = medication.name
            self.dosageAmountText = medication.dosage.amount.description
            self.dosageUnit = medication.dosage.unit
            self.instructions = medication.instructions ?? ""
            self.dailyDoseTimes = medication.schedule.dailyDoseTimes
        }
    }

    func save() async -> Medication? {
        guard !isSaving else {
            return nil
        }

        guard let dosageAmount = parseDosageAmount() else {
            errorMessage = "Enter a dosage greater than zero."
            return nil
        }

        isSaving = true
        errorMessage = nil
        savedMedication = nil
        didDeleteMedication = false

        defer {
            isSaving = false
        }

        do {
            let medication: Medication
            let scheduledDoses: [ScheduledDose]
            let isEditing: Bool

            switch mode {
            case .add:
                let result = try await addMedicationAndScheduleUseCase.execute(
                    input: AddMedicationInput(
                        name: name,
                        dosageAmount: dosageAmount,
                        dosageUnit: dosageUnit,
                        instructions: instructions,
                        dailyDoseTimes: dailyDoseTimes
                    )
                )
                medication = result.medication
                scheduledDoses = result.scheduledDoses
                isEditing = false

            case .edit(let existingMedication):
                let result = try await updateMedicationAndRescheduleUseCase.execute(
                    input: UpdateMedicationInput(
                        medicationID: existingMedication.id,
                        name: name,
                        dosageAmount: dosageAmount,
                        dosageUnit: dosageUnit,
                        instructions: instructions,
                        dailyDoseTimes: dailyDoseTimes
                    )
                )
                medication = result.medication
                scheduledDoses = result.scheduledDoses
                isEditing = true
            }

            savedMedication = medication
            await syncWidgetSnapshot()
            await syncNotifications(
                for: medication,
                scheduledDoses: scheduledDoses,
                replacingExistingRequests: isEditing
            )
            return medication
        } catch let error as AddMedicationAndScheduleUseCaseError {
            errorMessage = mapError(error)
            return nil
        } catch let error as UpdateMedicationAndRescheduleUseCaseError {
            errorMessage = mapError(error)
            return nil
        } catch let error as UpdateMedicationUseCaseError {
            errorMessage = mapError(error)
            return nil
        } catch {
            errorMessage = "We couldn't save this medication. Please try again."
            return nil
        }
    }

    func deactivate() async -> Medication? {
        guard !isSaving else {
            return nil
        }

        guard case .edit(let medication) = mode else {
            return nil
        }

        isSaving = true
        errorMessage = nil
        deactivatedMedication = nil
        didDeleteMedication = false

        defer {
            isSaving = false
        }

        do {
            let deactivatedMedication = try await deactivateMedicationUseCase.execute(medicationID: medication.id)
            self.deactivatedMedication = deactivatedMedication
            await syncWidgetSnapshot()
            await notificationScheduler?.removePendingNotifications(for: medication.id)
            return deactivatedMedication
        } catch let error as DeactivateMedicationUseCaseError {
            errorMessage = mapError(error)
            return nil
        } catch {
            errorMessage = "We couldn't save this medication. Please try again."
            return nil
        }
    }

    func deleteMedication() async -> Bool {
        guard !isSaving else {
            return false
        }

        guard case .edit(let medication) = mode else {
            return false
        }

        isSaving = true
        errorMessage = nil
        didDeleteMedication = false

        defer {
            isSaving = false
        }

        do {
            try await deleteMedicationUseCase.execute(medicationID: medication.id)
            didDeleteMedication = true
            await syncWidgetSnapshot()
            await notificationScheduler?.removePendingNotifications(for: medication.id)
            return true
        } catch let error as DeleteMedicationUseCaseError {
            errorMessage = mapError(error)
            return false
        } catch {
            errorMessage = "We couldn't delete this medication. Please try again."
            return false
        }
    }

    func addDoseTime(_ doseTime: DoseTime) {
        dailyDoseTimes.append(doseTime)
        dailyDoseTimes.sort {
            ($0.hour, $0.minute) < ($1.hour, $1.minute)
        }
    }

    func removeDoseTime(at index: Int) {
        guard dailyDoseTimes.indices.contains(index) else {
            return
        }

        dailyDoseTimes.remove(at: index)
    }

    private func parseDosageAmount() -> Decimal? {
        let trimmedText = dosageAmountText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            return nil
        }

        return Decimal(string: trimmedText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func mapError(_ error: AddMedicationUseCaseError) -> String {
        switch error {
        case .blankName:
            return "Enter a medication name."
        case .invalidDosage:
            return "Enter a dosage greater than zero."
        case .emptyDoseTimes:
            return "Add at least one dose time."
        case .duplicateDoseTimes:
            return "That dose time is already in the schedule."
        case .invalidSchedule:
            return "Check the dose schedule and try again."
        case .persistenceFailure:
            return "We couldn't save this medication. Please try again."
        }
    }

    private func mapError(_ error: AddMedicationAndScheduleUseCaseError) -> String {
        switch error {
        case .medicationCreationFailure(let addMedicationError):
            return mapError(addMedicationError)
        case .invalidSchedulingDateCalculation, .scheduleGenerationFailure:
            return "The medication was saved, but its upcoming doses couldn't be prepared. Please try again."
        }
    }

    private func mapError(_ error: UpdateMedicationUseCaseError) -> String {
        switch error {
        case .medicationNotFound:
            return "We couldn't find this medication."
        case .blankName:
            return "Enter a medication name."
        case .invalidDosage:
            return "Enter a dosage greater than zero."
        case .emptyDoseTimes:
            return "Add at least one dose time."
        case .duplicateDoseTimes:
            return "That dose time is already in the schedule."
        case .invalidSchedule:
            return "Check the dose schedule and try again."
        case .persistenceFailure:
            return "We couldn't save this medication. Please try again."
        }
    }

    private func mapError(_ error: UpdateMedicationAndRescheduleUseCaseError) -> String {
        switch error {
        case .medicationUpdateFailure(let updateMedicationError):
            return mapError(updateMedicationError)
        case .invalidSchedulingDateCalculation,
             .fetchScheduledDosesFailure,
             .deleteScheduledDosesFailure,
             .scheduleGenerationFailure:
            return "The medication was saved, but its upcoming doses couldn't be refreshed. Please try again."
        }
    }

    private func mapError(_ error: DeactivateMedicationUseCaseError) -> String {
        switch error {
        case .medicationNotFound:
            return "We couldn't find this medication."
        case .alreadyInactive:
            return "This medication is already inactive."
        case .persistenceFailure:
            return "We couldn't save this medication. Please try again."
        }
    }

    private func mapError(_ error: DeleteMedicationUseCaseError) -> String {
        switch error {
        case .medicationNotFound:
            return "This medication is no longer available."
        case .recordedHistoryExists:
            return "This medication has recorded dose history, so it can't be permanently deleted. Deactivate it instead to keep those records."
        case .fetchScheduledDosesFailure,
             .deleteScheduledDosesFailure,
             .deleteMedicationFailure:
            return "We couldn't delete this medication. Please try again."
        }
    }

    private func syncWidgetSnapshot() async {
        await widgetSnapshotSynchronizer?.sync(referenceDate: Date())
    }

    private func syncNotifications(
        for medication: Medication,
        scheduledDoses: [ScheduledDose],
        replacingExistingRequests: Bool
    ) async {
        guard let notificationScheduler else {
            return
        }

        if replacingExistingRequests {
            await notificationScheduler.rescheduleNotifications(
                for: medication.id,
                scheduledDoses: scheduledDoses,
                referenceDate: Date()
            )
        } else {
            await notificationScheduler.scheduleNotifications(
                for: scheduledDoses,
                referenceDate: Date()
            )
        }
    }
}
