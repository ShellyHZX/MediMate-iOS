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

    let mode: Mode

    private let addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase
    private let updateMedicationAndRescheduleUseCase: UpdateMedicationAndRescheduleUseCase
    private let deactivateMedicationUseCase: DeactivateMedicationUseCase

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

    init(
        mode: Mode,
        addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase,
        updateMedicationAndRescheduleUseCase: UpdateMedicationAndRescheduleUseCase,
        deactivateMedicationUseCase: DeactivateMedicationUseCase
    ) {
        self.mode = mode
        self.addMedicationAndScheduleUseCase = addMedicationAndScheduleUseCase
        self.updateMedicationAndRescheduleUseCase = updateMedicationAndRescheduleUseCase
        self.deactivateMedicationUseCase = deactivateMedicationUseCase
        self.isSaving = false
        self.errorMessage = nil
        self.savedMedication = nil
        self.deactivatedMedication = nil

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

        defer {
            isSaving = false
        }

        do {
            let medication: Medication

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
            }

            savedMedication = medication
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

        defer {
            isSaving = false
        }

        do {
            let deactivatedMedication = try await deactivateMedicationUseCase.execute(medicationID: medication.id)
            self.deactivatedMedication = deactivatedMedication
            return deactivatedMedication
        } catch let error as DeactivateMedicationUseCaseError {
            errorMessage = mapError(error)
            return nil
        } catch {
            errorMessage = "We couldn't save this medication. Please try again."
            return nil
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
}
