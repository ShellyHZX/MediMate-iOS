import CoreData
import Foundation

extension DoseTimeEntity {
    func toDomainDoseTime() throws -> DoseTime {
        guard id != nil else {
            throw CoreDataMappingError.missingRequiredValue(entity: "DoseTimeEntity", field: "id")
        }

        let hour = Int(hour)
        let minute = Int(minute)

        guard let doseTime = DoseTime(hour: hour, minute: minute) else {
            throw CoreDataMappingError.invalidDoseTime(hour: hour, minute: minute)
        }

        return doseTime
    }

    func apply(_ doseTime: DoseTime) {
        if id == nil {
            id = UUID()
        }

        hour = Int16(doseTime.hour)
        minute = Int16(doseTime.minute)
    }
}
