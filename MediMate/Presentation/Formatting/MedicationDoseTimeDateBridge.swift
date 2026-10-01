import Foundation

enum MedicationDoseTimeDateBridge {
    static var defaultDate: Date {
        guard let defaultDoseTime = DoseTime(hour: 9, minute: 0) else {
            return Date(timeIntervalSinceReferenceDate: 0)
        }

        return date(from: defaultDoseTime)
    }

    static func date(from doseTime: DoseTime, calendar: Calendar = .autoupdatingCurrent) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = doseTime.hour
        components.minute = doseTime.minute

        return calendar.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    static func doseTime(from date: Date, calendar: Calendar = .autoupdatingCurrent) -> DoseTime? {
        let components = calendar.dateComponents([.hour, .minute], from: date)

        guard let hour = components.hour, let minute = components.minute else {
            return nil
        }

        return DoseTime(hour: hour, minute: minute)
    }
}
