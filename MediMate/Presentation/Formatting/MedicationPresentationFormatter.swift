import Foundation

enum MedicationPresentationFormatter {
    static func dosage(_ dosage: Dosage) -> String {
        let amount = formatAmount(dosage.amount)

        switch dosage.unit {
        case .tablet:
            return "\(amount) \(dosage.amount == 1 ? "tablet" : "tablets")"
        case .capsule:
            return "\(amount) \(dosage.amount == 1 ? "capsule" : "capsules")"
        case .mg, .mcg, .g, .mL:
            return "\(amount) \(dosage.unit.rawValue)"
        }
    }

    static func doseTimes(_ doseTimes: [DoseTime]) -> String {
        doseTimes
            .map { time($0) }
            .joined(separator: " · ")
    }

    static func time(_ doseTime: DoseTime) -> String {
        var components = DateComponents()
        components.calendar = Calendar.autoupdatingCurrent
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = doseTime.hour
        components.minute = doseTime.minute

        guard let date = components.date else {
            return String(format: "%02d:%02d", doseTime.hour, doseTime.minute)
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = .autoupdatingCurrent

        return formatter.string(from: date)
    }

    private static func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = .autoupdatingCurrent

        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}
