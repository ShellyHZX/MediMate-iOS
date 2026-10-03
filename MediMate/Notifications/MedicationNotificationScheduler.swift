import Foundation
import UserNotifications

protocol MedicationNotificationScheduling {
    func requestAuthorizationIfNeeded() async -> Bool
    func scheduleNotifications(for scheduledDoses: [ScheduledDose], referenceDate: Date) async
    func rescheduleNotifications(for medicationID: UUID, scheduledDoses: [ScheduledDose], referenceDate: Date) async
    func removePendingNotifications(for medicationID: UUID) async
}

struct MedicationNotificationScheduler: MedicationNotificationScheduling {
    static let medicationDueCategoryIdentifier = "MEDICATION_DUE"

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.center = center
        self.calendar = calendar
    }

    static func registerMedicationDueCategory(center: UNUserNotificationCenter = .current()) {
        let category = UNNotificationCategory(
            identifier: medicationDueCategoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func scheduleNotifications(for scheduledDoses: [ScheduledDose], referenceDate: Date = Date()) async {
        let futureDoses = scheduledDoses
            .filter { $0.scheduledAt > referenceDate }
            .filter(\.isNotificationEligible)

        guard !futureDoses.isEmpty else {
            return
        }

        guard await requestAuthorizationIfNeeded() else {
            return
        }

        let moments = Dictionary(grouping: futureDoses) { calendarMinute(for: $0.scheduledAt) }

        for moment in moments.values {
            guard let request = notificationRequest(for: moment.sorted { $0.medicationName < $1.medicationName }) else {
                continue
            }

            do {
                try await center.add(request)
            } catch {
                continue
            }
        }
    }

    func rescheduleNotifications(
        for medicationID: UUID,
        scheduledDoses: [ScheduledDose],
        referenceDate: Date = Date()
    ) async {
        await removePendingNotifications(for: medicationID)
        await scheduleNotifications(for: scheduledDoses, referenceDate: referenceDate)
    }

    func removePendingNotifications(for medicationID: UUID) async {
        let medicationIDString = medicationID.uuidString
        let pendingRequests = await center.pendingNotificationRequests()
        let matchingIdentifiers = pendingRequests.compactMap { request -> String? in
            let userInfo = request.content.userInfo

            if userInfo[PayloadKey.medicationID] as? String == medicationIDString {
                return request.identifier
            }

            if let medicationIDs = userInfo[PayloadKey.medicationIDs] as? [String],
               medicationIDs.contains(medicationIDString) {
                return request.identifier
            }

            return nil
        }

        guard !matchingIdentifiers.isEmpty else {
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: matchingIdentifiers)
    }

    private func notificationRequest(for doses: [ScheduledDose]) -> UNNotificationRequest? {
        guard let firstDose = doses.first else {
            return nil
        }

        let scheduledAt = calendarMinute(for: firstDose.scheduledAt)
        let content = UNMutableNotificationContent()
        content.title = "Medication reminder"
        content.body = bodyText(for: doses)
        content.sound = .default
        content.categoryIdentifier = Self.medicationDueCategoryIdentifier
        content.userInfo = userInfo(for: doses, scheduledAt: scheduledAt)

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: requestIdentifier(for: doses, scheduledAt: scheduledAt),
            content: content,
            trigger: trigger
        )
    }

    private func bodyText(for doses: [ScheduledDose]) -> String {
        guard doses.count == 1, let dose = doses.first else {
            return "\(doses.count) medications scheduled"
        }

        return "\(dose.medicationName) · \(Self.dosageText(for: dose.dosage))"
    }

    private func userInfo(for doses: [ScheduledDose], scheduledAt: Date) -> [String: Any] {
        let medicationNames = doses.map(\.medicationName)
        let dosageTexts = doses.map { Self.dosageText(for: $0.dosage) }
        let medicationIDs = doses.map { $0.medicationID.uuidString }

        var payload: [String: Any] = [
            PayloadKey.medicationName: medicationNames.first ?? "",
            PayloadKey.dosageText: dosageTexts.first ?? "",
            PayloadKey.scheduledAt: scheduledAt.timeIntervalSince1970,
            PayloadKey.medicationNames: medicationNames,
            PayloadKey.dosageTexts: dosageTexts,
            PayloadKey.medicationIDs: medicationIDs,
            PayloadKey.medicationCount: doses.count
        ]

        if let medicationID = medicationIDs.first {
            payload[PayloadKey.medicationID] = medicationID
        }

        return payload
    }

    private func requestIdentifier(for doses: [ScheduledDose], scheduledAt: Date) -> String {
        let timestamp = Int(scheduledAt.timeIntervalSince1970)

        if doses.count == 1, let dose = doses.first {
            return "medication.\(dose.medicationID.uuidString).\(timestamp)"
        }

        let medicationIDs = doses.map { $0.medicationID.uuidString }.sorted().joined(separator: ".")
        return "medicationMoment.\(timestamp).\(medicationIDs)"
    }

    private func calendarMinute(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }

    private enum PayloadKey {
        static let medicationID = "medicationID"
        static let medicationIDs = "medicationIDs"
        static let medicationName = "medicationName"
        static let medicationNames = "medicationNames"
        static let dosageText = "dosageText"
        static let dosageTexts = "dosageTexts"
        static let scheduledAt = "scheduledAt"
        static let medicationCount = "medicationCount"
    }

    private static func dosageText(for dosage: Dosage) -> String {
        "\(dosage.amount) \(dosage.unit.rawValue)"
    }
}

private extension ScheduledDose {
    var isNotificationEligible: Bool {
        switch status {
        case .upcoming, .due:
            return true
        case .taken, .skipped, .missed:
            return false
        }
    }
}
