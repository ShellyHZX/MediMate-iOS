import UIKit
import UserNotifications
import UserNotificationsUI

final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet private var label: UILabel?

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let timeLabel = UILabel()
    private let primaryLabel = UILabel()
    private let secondaryLabel = UILabel()
    private let medicationListStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let payload = NotificationPayload(
            userInfo: content.userInfo,
            fallbackTitle: content.title,
            fallbackBody: content.body
        )

        apply(payload)
    }

    private func configureView() {
        label?.removeFromSuperview()

        view.backgroundColor = NotificationTheme.background
        preferredContentSize = CGSize(width: view.bounds.width, height: 190)

        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = NotificationTheme.secondaryText
        titleLabel.numberOfLines = 1

        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = NotificationTheme.accent
        statusLabel.backgroundColor = NotificationTheme.accent.withAlphaComponent(0.14)
        statusLabel.layer.cornerRadius = 12
        statusLabel.layer.masksToBounds = true
        statusLabel.textAlignment = .center
        statusLabel.text = "Due now"

        timeLabel.font = .systemFont(ofSize: 36, weight: .bold)
        timeLabel.adjustsFontForContentSizeCategory = true
        timeLabel.textColor = NotificationTheme.primaryText
        timeLabel.numberOfLines = 1
        timeLabel.minimumScaleFactor = 0.78

        primaryLabel.font = .preferredFont(forTextStyle: .title3)
        primaryLabel.adjustsFontForContentSizeCategory = true
        primaryLabel.textColor = NotificationTheme.primaryText
        primaryLabel.numberOfLines = 2

        secondaryLabel.font = .preferredFont(forTextStyle: .subheadline)
        secondaryLabel.adjustsFontForContentSizeCategory = true
        secondaryLabel.textColor = NotificationTheme.secondaryText
        secondaryLabel.numberOfLines = 2

        medicationListStack.axis = .vertical
        medicationListStack.alignment = .leading
        medicationListStack.spacing = 3

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, UIView(), statusLabel])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8

        let contentStack = UIStackView(arrangedSubviews: [
            headerStack,
            timeLabel,
            primaryLabel,
            secondaryLabel,
            medicationListStack
        ])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 8
        view.addSubview(contentStack)

        NSLayoutConstraint.activate([
            statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            contentStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16)
        ])
    }

    private func apply(_ payload: NotificationPayload) {
        titleLabel.text = payload.title
        timeLabel.text = payload.scheduledTimeText

        medicationListStack.arrangedSubviews.forEach { view in
            medicationListStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if payload.medicationCount > 1 {
            primaryLabel.text = "\(payload.medicationCount) medications scheduled"
            secondaryLabel.text = nil
            secondaryLabel.isHidden = true
            medicationListStack.isHidden = false

            for name in payload.visibleMedicationNames {
                medicationListStack.addArrangedSubview(listLabel(text: name))
            }

            if payload.remainingMedicationCount > 0 {
                medicationListStack.addArrangedSubview(listLabel(text: "+ \(payload.remainingMedicationCount) more"))
            }
        } else {
            primaryLabel.text = payload.primaryMedicationName
            secondaryLabel.text = payload.primaryDosageText
            secondaryLabel.isHidden = payload.primaryDosageText.isEmpty
            medicationListStack.isHidden = true
        }
    }

    private func listLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = NotificationTheme.primaryText
        label.numberOfLines = 1
        return label
    }
}

private struct NotificationPayload {
    let title: String
    let scheduledTimeText: String
    let primaryMedicationName: String
    let primaryDosageText: String
    let medicationCount: Int
    let visibleMedicationNames: [String]

    var remainingMedicationCount: Int {
        max(0, medicationCount - visibleMedicationNames.count)
    }

    init(userInfo: [AnyHashable: Any], fallbackTitle: String, fallbackBody: String) {
        let medicationNames = Self.stringArray(for: PayloadKey.medicationNames, in: userInfo)
        let dosageTexts = Self.stringArray(for: PayloadKey.dosageTexts, in: userInfo)
        let medicationName = userInfo[PayloadKey.medicationName] as? String
        let dosageText = userInfo[PayloadKey.dosageText] as? String
        let medicationCount = userInfo[PayloadKey.medicationCount] as? Int

        self.title = fallbackTitle.isEmpty ? "Medication reminder" : fallbackTitle
        self.scheduledTimeText = Self.scheduledTimeText(from: userInfo[PayloadKey.scheduledAt])
        self.primaryMedicationName = medicationName?.isEmpty == false ? medicationName ?? "" : fallbackBody
        self.primaryDosageText = dosageText ?? dosageTexts.first ?? ""
        self.medicationCount = medicationCount ?? max(1, medicationNames.count)
        self.visibleMedicationNames = Array(medicationNames.prefix(3))
    }

    private static func stringArray(for key: String, in userInfo: [AnyHashable: Any]) -> [String] {
        if let values = userInfo[key] as? [String] {
            return values.filter { !$0.isEmpty }
        }

        if let values = userInfo[key] as? NSArray {
            return values.compactMap { $0 as? String }.filter { !$0.isEmpty }
        }

        return []
    }

    private static func scheduledTimeText(from value: Any?) -> String {
        let date: Date?

        switch value {
        case let timestamp as TimeInterval:
            date = Date(timeIntervalSince1970: timestamp)
        case let timestamp as NSNumber:
            date = Date(timeIntervalSince1970: timestamp.doubleValue)
        case let dateValue as Date:
            date = dateValue
        default:
            date = nil
        }

        guard let date else {
            return ""
        }

        return DateFormatter.medicationReminderTime.string(from: date)
    }

    private enum PayloadKey {
        static let medicationName = "medicationName"
        static let medicationNames = "medicationNames"
        static let dosageText = "dosageText"
        static let dosageTexts = "dosageTexts"
        static let scheduledAt = "scheduledAt"
        static let medicationCount = "medicationCount"
    }
}

private enum NotificationTheme {
    static let background = UIColor(red: 0.97, green: 0.95, blue: 0.91, alpha: 1)
    static let primaryText = UIColor(red: 0.10, green: 0.13, blue: 0.11, alpha: 1)
    static let secondaryText = UIColor(red: 0.42, green: 0.44, blue: 0.39, alpha: 1)
    static let accent = UIColor(red: 0.20, green: 0.48, blue: 0.42, alpha: 1)
}

private extension DateFormatter {
    static let medicationReminderTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()
}
