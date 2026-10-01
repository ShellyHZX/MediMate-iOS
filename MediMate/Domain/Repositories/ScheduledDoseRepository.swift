import Foundation

protocol ScheduledDoseRepository {
    func fetchScheduledDose(id: UUID) async throws -> ScheduledDose?
    func fetchScheduledDoses(from startDate: Date, to endDate: Date) async throws -> [ScheduledDose]
    func saveScheduledDose(_ scheduledDose: ScheduledDose) async throws
    func saveScheduledDoses(_ scheduledDoses: [ScheduledDose]) async throws
}
