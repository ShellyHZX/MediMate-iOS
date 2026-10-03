import SwiftUI
import WidgetKit

struct MediMateWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MedicationWidgetEntry {
        MedicationWidgetEntry(
            date: Date(),
            snapshot: MedicationWidgetSnapshot.placeholder,
            display: .upcoming(MedicationWidgetSnapshot.placeholder.moments[0])
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MedicationWidgetEntry) -> Void) {
        let snapshot = readSnapshot() ?? MedicationWidgetSnapshot.placeholder
        completion(entry(for: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MedicationWidgetEntry>) -> Void) {
        let snapshot = readSnapshot()
        let now = Date()

        guard let snapshot else {
            completion(Timeline(entries: [MedicationWidgetEntry(date: now, snapshot: nil, display: .noSnapshot)], policy: .after(nextDay(from: now))))
            return
        }

        let entryDates = timelineDates(for: snapshot, now: now)
        let entries = entryDates.map { entry(for: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func readSnapshot() -> MedicationWidgetSnapshot? {
        do {
            return try MedicationWidgetSnapshotStore().read()
        } catch {
            return nil
        }
    }

    private func entry(for date: Date, snapshot: MedicationWidgetSnapshot) -> MedicationWidgetEntry {
        MedicationWidgetEntry(
            date: date,
            snapshot: snapshot,
            display: MedicationWidgetDisplayState.select(from: snapshot, at: date)
        )
    }

    private func timelineDates(for snapshot: MedicationWidgetSnapshot, now: Date) -> [Date] {
        var dates = Set<Date>([now])

        for moment in snapshot.moments where moment.hasUnresolvedDoses {
            if moment.scheduledAt > now {
                dates.insert(moment.scheduledAt)
            }

            if let notRecordedDate = Calendar.current.date(byAdding: .minute, value: 15, to: moment.scheduledAt),
               notRecordedDate > now {
                dates.insert(notRecordedDate)
            }
        }

        dates.insert(nextDay(from: now))
        return dates.sorted()
    }

    private func nextDay(from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date.addingTimeInterval(3600)
    }
}

struct MedicationWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: MedicationWidgetSnapshot?
    let display: MedicationWidgetDisplayState
}

enum MedicationWidgetDisplayState: Equatable {
    case noSnapshot
    case empty
    case upcoming(MedicationWidgetMoment)
    case due(MedicationWidgetMoment)
    case notRecorded(MedicationWidgetMoment)
    case recorded(next: MedicationWidgetMoment?)
    case allRecorded

    static func select(from snapshot: MedicationWidgetSnapshot, at date: Date) -> MedicationWidgetDisplayState {
        guard snapshot.totalCount > 0 else {
            return .empty
        }

        let unresolvedMoments = snapshot.moments.filter(\.hasUnresolvedDoses)

        if let reached = unresolvedMoments.first(where: { $0.scheduledAt <= date }) {
            if date.timeIntervalSince(reached.scheduledAt) >= 60 {
                return .notRecorded(reached)
            }

            return .due(reached)
        }

        if let upcoming = unresolvedMoments.first(where: { $0.scheduledAt > date }) {
            let hasFinalizedEarlierMoment = snapshot.moments.contains { moment in
                moment.scheduledAt <= date && moment.finalizedCount > 0
            }

            if hasFinalizedEarlierMoment {
                return .recorded(next: upcoming)
            }

            return .upcoming(upcoming)
        }

        return .allRecorded
    }
}

struct MediMateWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MedicationWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumMedicationWidgetView(entry: entry)
            default:
                SmallMedicationWidgetView(entry: entry)
            }
        }
        .widgetURL(MedicationWidgetSharedConfiguration.todayURL)
    }
}

private struct SmallMedicationWidgetView: View {
    let entry: MedicationWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Today")
                .font(.caption.weight(.bold))
                .foregroundStyle(WidgetTheme.secondaryText)

            switch entry.display {
            case .noSnapshot:
                WidgetEmptyContent(title: "Open MediMate", message: "Update Today")

            case .empty:
                WidgetEmptyContent(title: "No doses today", message: "You're all set")

            case .upcoming(let moment), .due(let moment), .notRecorded(let moment):
                StatusPill(state: entry.display, entryDate: entry.date, scheduledAt: moment.scheduledAt, prominent: true)
                MomentTime(moment: moment, size: .large)
                Spacer(minLength: 0)
                Text(summaryText(for: entry.display, moment: moment))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetTheme.primaryText)
                    .lineLimit(2)

            case .recorded(let next):
                if let next {
                    StatusPill(state: .upcoming(next), entryDate: entry.date, scheduledAt: next.scheduledAt, prominent: true)
                    MomentTime(moment: next, size: .large)
                    Spacer(minLength: 0)
                    Text(WidgetText.medicationsLeft(next.medications.count))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetTheme.secondaryText)
                } else {
                    StatusPill(state: .allRecorded, entryDate: entry.date, scheduledAt: entry.date, prominent: true)
                }

            case .allRecorded:
                StatusPill(state: entry.display, entryDate: entry.date, scheduledAt: entry.date, prominent: true)
                Spacer(minLength: 0)
                if let snapshot = entry.snapshot {
                    Text("\(snapshot.completedCount) of \(snapshot.totalCount) recorded")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(WidgetTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .privacySensitive()
    }

    private func summaryText(for state: MedicationWidgetDisplayState, moment: MedicationWidgetMoment) -> String {
        switch state {
        case .upcoming:
            return WidgetText.medicationsLeft(moment.medications.count)
        case .due:
            return WidgetText.medicationsDue(moment.medications.count)
        case .notRecorded:
            return "Tap to review"
        default:
            return ""
        }
    }
}

private struct MediumMedicationWidgetView: View {
    let entry: MedicationWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WidgetTheme.primaryText)

                Spacer()

                if let snapshot = entry.snapshot {
                    Text("\(snapshot.completedCount) of \(snapshot.totalCount) recorded")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetTheme.secondaryText)
                }
            }

            switch entry.display {
            case .noSnapshot:
                WidgetEmptyContent(title: "Open MediMate", message: "Widget data will appear here")

            case .empty:
                WidgetEmptyContent(title: "No doses today", message: "You're all set")

            case .upcoming(let moment), .due(let moment), .notRecorded(let moment):
                VStack(alignment: .leading, spacing: 7) {
                    StatusPill(state: entry.display, entryDate: entry.date, scheduledAt: moment.scheduledAt, prominent: true)
                    MomentTime(moment: moment, size: .large)
                }

                MedicationContext(moment: moment)

            case .recorded(let next):
                if let next {
                    VStack(alignment: .leading, spacing: 7) {
                        StatusPill(state: .upcoming(next), entryDate: entry.date, scheduledAt: next.scheduledAt, prominent: true)
                        MomentTime(moment: next, size: .large)
                    }

                    MedicationContext(moment: next)
                } else {
                    StatusPill(state: .allRecorded, entryDate: entry.date, scheduledAt: entry.date, prominent: true)
                }

            case .allRecorded:
                Spacer(minLength: 0)
                StatusPill(state: entry.display, entryDate: entry.date, scheduledAt: entry.date, prominent: true)
                if let snapshot = entry.snapshot {
                    Text("\(snapshot.completedCount) of \(snapshot.totalCount) recorded")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetTheme.primaryText)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct MomentHeader: View {
    let moment: MedicationWidgetMoment
    let state: MedicationWidgetDisplayState
    let entryDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MomentTime(moment: moment, size: .regular)
            StatusPill(state: state, entryDate: entryDate, scheduledAt: moment.scheduledAt)
        }
    }
}

private struct MomentTime: View {
    enum Size {
        case regular
        case large
    }

    let moment: MedicationWidgetMoment
    var size: Size = .regular

    var body: some View {
        Text(moment.scheduledAt, style: .time)
            .font(size == .large ? .title.weight(.bold) : .title3.weight(.bold))
            .foregroundStyle(WidgetTheme.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct PrimaryMedication: View {
    let moment: MedicationWidgetMoment
    let compact: Bool

    var body: some View {
        if let first = moment.medications.first {
            VStack(alignment: .leading, spacing: 3) {
                Text(first.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WidgetTheme.primaryText)
                    .lineLimit(1)
                    .privacySensitive()

                if moment.medications.count == 1 {
                    Text(first.dosageText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WidgetTheme.secondaryText)
                        .lineLimit(1)
                } else {
                    Text("+ \(moment.medications.count - 1) more")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WidgetTheme.secondaryText)
                }
            }
        }
    }
}

private struct MedicationContext: View {
    let moment: MedicationWidgetMoment

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if moment.medications.count == 1, let first = moment.medications.first {
                Text(first.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WidgetTheme.primaryText)
                    .lineLimit(1)
                    .privacySensitive()

                Text(first.dosageText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WidgetTheme.secondaryText)
                    .lineLimit(1)
            } else {
                Text("\(moment.medications.count) medications")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WidgetTheme.primaryText)

                Text(namesSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WidgetTheme.secondaryText)
                    .lineLimit(1)
                    .privacySensitive()
            }
        }
    }

    private var namesSummary: String {
        let visibleNames = moment.medications.prefix(2).map(\.name)
        let remainingCount = moment.medications.count - visibleNames.count

        if remainingCount > 0 {
            return (visibleNames + ["+\(remainingCount) more"]).joined(separator: " · ")
        }

        return visibleNames.joined(separator: " · ")
    }
}

private struct StatusPill: View {
    let state: MedicationWidgetDisplayState
    let entryDate: Date
    let scheduledAt: Date
    var prominent = false

    var body: some View {
        Label {
            Text(text)
                .font((prominent ? Font.headline : Font.caption).weight(.bold))
        } icon: {
            Image(systemName: symbol)
                .font((prominent ? Font.subheadline : Font.caption).weight(.bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, prominent ? 10 : 8)
        .padding(.vertical, prominent ? 6 : 5)
        .background(color.opacity(prominent ? 0.18 : 0.14), in: Capsule())
    }

    private var text: String {
        switch state {
        case .upcoming:
            return "Up next"
        case .due:
            return "Due now"
        case .notRecorded:
            return "Not recorded yet"
        case .recorded:
            return "Up next"
        case .allRecorded:
            return "All set"
        case .empty, .noSnapshot:
            return "Today"
        }
    }

    private var symbol: String {
        switch state {
        case .upcoming:
            return "clock"
        case .due:
            return "exclamationmark.circle"
        case .notRecorded:
            return "questionmark.circle"
        case .recorded:
            return "clock"
        case .allRecorded:
            return "checkmark.circle"
        case .empty, .noSnapshot:
            return "calendar"
        }
    }

    private var color: Color {
        switch state {
        case .upcoming:
            return WidgetTheme.accent
        case .due:
            return WidgetTheme.due
        case .notRecorded:
            return WidgetTheme.notRecorded
        case .recorded:
            return WidgetTheme.accent
        case .allRecorded:
            return WidgetTheme.recorded
        case .empty, .noSnapshot:
            return WidgetTheme.secondaryText
        }
    }
}

private struct WidgetEmptyContent: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(WidgetTheme.primaryText)

            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(WidgetTheme.secondaryText)
        }
    }
}

private enum WidgetText {
    static func medicationCount(_ count: Int) -> String {
        count == 1 ? "1 medication scheduled" : "\(count) medications scheduled"
    }

    static func medicationsLeft(_ count: Int) -> String {
        count == 1 ? "1 medication left" : "\(count) medications left"
    }

    static func medicationsDue(_ count: Int) -> String {
        count == 1 ? "1 medication due" : "\(count) medications due"
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = .autoupdatingCurrent
        return formatter.string(from: date)
    }

    static func relativeUntil(_ date: Date, from referenceDate: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(referenceDate)))
        let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))

        if minutes < 60 {
            return "In \(minutes) min"
        }

        let hours = Int(round(Double(minutes) / 60.0))
        return hours == 1 ? "In 1 hour" : "In \(hours) hours"
    }
}

private enum WidgetTheme {
    static let background = Color("WidgetBackground")
    static let primaryText = Color(red: 0.10, green: 0.13, blue: 0.11)
    static let secondaryText = Color.secondary
    static let accent = Color(red: 0.20, green: 0.48, blue: 0.42)
    static let due = Color(red: 0.72, green: 0.45, blue: 0.10)
    static let notRecorded = Color(red: 0.70, green: 0.34, blue: 0.27)
    static let recorded = Color(red: 0.24, green: 0.55, blue: 0.34)
}

struct MediMateWidget: Widget {
    let kind: String = MedicationWidgetSharedConfiguration.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MediMateWidgetProvider()) { entry in
            MediMateWidgetEntryView(entry: entry)
                .containerBackground(WidgetTheme.background, for: .widget)
        }
        .configurationDisplayName("MediMate")
        .description("See your next medication moment for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension MedicationWidgetSnapshot {
    static var placeholder: MedicationWidgetSnapshot {
        MedicationWidgetSnapshot(
            generatedAt: Date(),
            dayStart: Calendar.current.startOfDay(for: Date()),
            completedCount: 1,
            totalCount: 3,
            moments: [
                MedicationWidgetMoment(
                    scheduledAt: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                    medications: [
                        MedicationWidgetItem(
                            id: UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!,
                            name: "Vitamin D",
                            dosageText: "1 capsule",
                            isFinalized: false
                        )
                    ],
                    hasUnresolvedDoses: true,
                    finalizedCount: 0
                )
            ]
        )
    }
}
