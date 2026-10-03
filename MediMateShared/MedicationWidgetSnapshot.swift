import Foundation

enum MedicationWidgetSharedConfiguration {
    static let appGroupIdentifier = "group.com.shellyh.MediMate"
    static let snapshotKey = "medimate.widget.snapshot.v1"
    static let widgetKind = "MediMateWidget"
    static let todayURL = URL(string: "medimate://today")!
}

struct MedicationWidgetSnapshot: Codable, Equatable, Sendable {
    let generatedAt: Date
    let dayStart: Date
    let completedCount: Int
    let totalCount: Int
    let moments: [MedicationWidgetMoment]
}

struct MedicationWidgetMoment: Codable, Equatable, Sendable, Identifiable {
    let scheduledAt: Date
    let medications: [MedicationWidgetItem]
    let hasUnresolvedDoses: Bool
    let finalizedCount: Int

    var id: Date {
        scheduledAt
    }
}

struct MedicationWidgetItem: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let dosageText: String
    let isFinalized: Bool
}

enum MedicationWidgetSnapshotStoreError: Error, Equatable {
    case missingAppGroupSuite(String)
    case encodingFailed
    case decodingFailed
}

struct MedicationWidgetSnapshotStore {
    private let suiteName: String
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        suiteName: String = MedicationWidgetSharedConfiguration.appGroupIdentifier,
        key: String = MedicationWidgetSharedConfiguration.snapshotKey
    ) {
        self.suiteName = suiteName
        self.key = key

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func write(_ snapshot: MedicationWidgetSnapshot) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw MedicationWidgetSnapshotStoreError.missingAppGroupSuite(suiteName)
        }

        do {
            defaults.set(try encoder.encode(snapshot), forKey: key)
        } catch {
            throw MedicationWidgetSnapshotStoreError.encodingFailed
        }
    }

    func read() throws -> MedicationWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw MedicationWidgetSnapshotStoreError.missingAppGroupSuite(suiteName)
        }

        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        do {
            return try decoder.decode(MedicationWidgetSnapshot.self, from: data)
        } catch {
            throw MedicationWidgetSnapshotStoreError.decodingFailed
        }
    }
}
