import Foundation
@testable import MediMate

enum MockScheduledDoseRepositoryError: Error {
    case requestedFailure
}

final class MockScheduledDoseRepository: ScheduledDoseRepository {
    var scheduledDoseByID: [UUID: ScheduledDose] = [:]
    var scheduledDosesInRange: [ScheduledDose] = []

    var fetchScheduledDoseError: Error?
    var fetchScheduledDosesError: Error?
    var saveScheduledDoseError: Error?
    var saveScheduledDosesError: Error?
    var deleteScheduledDosesError: Error?

    private(set) var fetchedScheduledDoseIDs: [UUID] = []
    private(set) var fetchedRangeRequests: [(startDate: Date, endDate: Date)] = []
    private(set) var savedScheduledDoses: [ScheduledDose] = []
    private(set) var batchSavedScheduledDoses: [[ScheduledDose]] = []
    private(set) var deletedScheduledDoseIDs: [[UUID]] = []

    func fetchScheduledDose(id: UUID) async throws -> ScheduledDose? {
        fetchedScheduledDoseIDs.append(id)

        if let fetchScheduledDoseError {
            throw fetchScheduledDoseError
        }

        return scheduledDoseByID[id]
    }

    func fetchScheduledDoses(from startDate: Date, to endDate: Date) async throws -> [ScheduledDose] {
        fetchedRangeRequests.append((startDate, endDate))

        if let fetchScheduledDosesError {
            throw fetchScheduledDosesError
        }

        return scheduledDosesInRange.filter {
            $0.scheduledAt >= startDate && $0.scheduledAt < endDate
        }
    }

    func saveScheduledDose(_ scheduledDose: ScheduledDose) async throws {
        if let saveScheduledDoseError {
            throw saveScheduledDoseError
        }

        savedScheduledDoses.append(scheduledDose)
        scheduledDoseByID[scheduledDose.id] = scheduledDose

        if let index = scheduledDosesInRange.firstIndex(where: { $0.id == scheduledDose.id }) {
            scheduledDosesInRange[index] = scheduledDose
        }
    }

    func saveScheduledDoses(_ scheduledDoses: [ScheduledDose]) async throws {
        if let saveScheduledDosesError {
            throw saveScheduledDosesError
        }

        batchSavedScheduledDoses.append(scheduledDoses)

        for scheduledDose in scheduledDoses {
            scheduledDoseByID[scheduledDose.id] = scheduledDose

            if let index = scheduledDosesInRange.firstIndex(where: { $0.id == scheduledDose.id }) {
                scheduledDosesInRange[index] = scheduledDose
            } else {
                scheduledDosesInRange.append(scheduledDose)
            }
        }
    }

    func deleteScheduledDoses(ids: [UUID]) async throws {
        deletedScheduledDoseIDs.append(ids)

        if let deleteScheduledDosesError {
            throw deleteScheduledDosesError
        }

        guard !ids.isEmpty else {
            return
        }

        let idSet = Set(ids)
        scheduledDoseByID = scheduledDoseByID.filter { !idSet.contains($0.key) }
        scheduledDosesInRange.removeAll { idSet.contains($0.id) }
    }
}
