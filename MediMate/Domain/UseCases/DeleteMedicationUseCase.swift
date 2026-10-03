import Foundation

enum DeleteMedicationUseCaseError: Error, Equatable {
    case medicationNotFound
    case recordedHistoryExists
    case fetchScheduledDosesFailure
    case deleteScheduledDosesFailure
    case deleteMedicationFailure
}

struct DeleteMedicationUseCase {
    private let medicationRepository: MedicationRepository
    private let scheduledDoseRepository: ScheduledDoseRepository

    init(
        medicationRepository: MedicationRepository,
        scheduledDoseRepository: ScheduledDoseRepository
    ) {
        self.medicationRepository = medicationRepository
        self.scheduledDoseRepository = scheduledDoseRepository
    }

    func execute(medicationID: UUID) async throws {
        let medication: Medication

        do {
            guard let fetchedMedication = try await medicationRepository.fetchMedication(id: medicationID) else {
                throw DeleteMedicationUseCaseError.medicationNotFound
            }

            medication = fetchedMedication
        } catch let error as DeleteMedicationUseCaseError {
            throw error
        } catch {
            throw DeleteMedicationUseCaseError.deleteMedicationFailure
        }

        let scheduledDoses: [ScheduledDose]

        do {
            scheduledDoses = try await scheduledDoseRepository.fetchScheduledDoses(medicationID: medication.id)
        } catch {
            throw DeleteMedicationUseCaseError.fetchScheduledDosesFailure
        }

        guard !scheduledDoses.contains(where: hasRecordedHistory) else {
            throw DeleteMedicationUseCaseError.recordedHistoryExists
        }

        do {
            try await scheduledDoseRepository.deleteScheduledDoses(ids: scheduledDoses.map(\.id))
        } catch {
            throw DeleteMedicationUseCaseError.deleteScheduledDosesFailure
        }

        do {
            try await medicationRepository.deleteMedication(id: medication.id)
        } catch {
            throw DeleteMedicationUseCaseError.deleteMedicationFailure
        }
    }

    private func hasRecordedHistory(_ scheduledDose: ScheduledDose) -> Bool {
        switch scheduledDose.status {
        case .taken, .skipped, .missed:
            return true
        case .upcoming, .due:
            return false
        }
    }
}
