import Foundation

enum RecordMedicationMomentAsTakenUseCaseError: Error, Equatable {
    case emptyDoseSelection
    case doseNotFound
    case doseAlreadyTaken
    case doseWasSkipped
    case persistenceFailure
}

struct RecordMedicationMomentAsTakenUseCase {
    private let scheduledDoseRepository: ScheduledDoseRepository

    init(scheduledDoseRepository: ScheduledDoseRepository) {
        self.scheduledDoseRepository = scheduledDoseRepository
    }

    func execute(
        scheduledDoseIDs: [UUID],
        takenAt: Date
    ) async throws -> [ScheduledDose] {
        guard !scheduledDoseIDs.isEmpty else {
            throw RecordMedicationMomentAsTakenUseCaseError.emptyDoseSelection
        }

        var updatedDoses: [ScheduledDose] = []

        for scheduledDoseID in scheduledDoseIDs {
            let scheduledDose: ScheduledDose

            do {
                guard let fetchedDose = try await scheduledDoseRepository.fetchScheduledDose(id: scheduledDoseID) else {
                    throw RecordMedicationMomentAsTakenUseCaseError.doseNotFound
                }

                scheduledDose = fetchedDose
            } catch let error as RecordMedicationMomentAsTakenUseCaseError {
                throw error
            } catch {
                throw RecordMedicationMomentAsTakenUseCaseError.persistenceFailure
            }

            switch scheduledDose.status {
            case .upcoming, .due, .missed:
                updatedDoses.append(
                    ScheduledDose(
                        id: scheduledDose.id,
                        medicationID: scheduledDose.medicationID,
                        medicationName: scheduledDose.medicationName,
                        dosage: scheduledDose.dosage,
                        scheduledAt: scheduledDose.scheduledAt,
                        status: .taken,
                        takenAt: takenAt
                    )
                )

            case .taken:
                throw RecordMedicationMomentAsTakenUseCaseError.doseAlreadyTaken

            case .skipped:
                throw RecordMedicationMomentAsTakenUseCaseError.doseWasSkipped
            }
        }

        do {
            try await scheduledDoseRepository.saveScheduledDoses(updatedDoses)
            return updatedDoses
        } catch {
            throw RecordMedicationMomentAsTakenUseCaseError.persistenceFailure
        }
    }
}
