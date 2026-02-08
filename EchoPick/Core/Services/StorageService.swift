import Foundation
import SwiftData

/// 本地数据持久化服务 — SwiftData
/// 所有数据存储在设备本地，通过 iCloud 可选同步
@MainActor
final class StorageService {
    static let shared = StorageService()

    let container: ModelContainer
    let context: ModelContext

    private init() {
        let schema = Schema([EchoRecord.self, Pick.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic  // 自动 iCloud 同步
        )

        do {
            container = try ModelContainer(for: schema, configurations: [config])
            context = container.mainContext
        } catch {
            fatalError("SwiftData 初始化失败: \(error)")
        }
    }

    // MARK: - Echo Records

    func saveRecord(_ record: EchoRecord) {
        context.insert(record)
        try? context.save()
    }

    func deleteRecord(_ record: EchoRecord) {
        // Delete associated picks
        let recordId = record.id
        let pickDescriptor = FetchDescriptor<Pick>(
            predicate: #Predicate<Pick> { $0.recordId == recordId }
        )
        if let picks = try? context.fetch(pickDescriptor) {
            for pick in picks { context.delete(pick) }
        }
        // Delete audio files
        let engine = AudioEngine()
        engine.deleteSession(sessionId: record.id.uuidString)
        // Delete record
        context.delete(record)
        try? context.save()
    }

    func fetchRecords() -> [EchoRecord] {
        var descriptor = FetchDescriptor<EchoRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchTodayRecords() -> [EchoRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        var descriptor = FetchDescriptor<EchoRecord>(
            predicate: #Predicate<EchoRecord> { $0.createdAt >= startOfDay },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Picks

    func savePick(_ pick: Pick) {
        context.insert(pick)
        try? context.save()
    }

    func savePicks(_ picks: [Pick]) {
        for pick in picks { context.insert(pick) }
        try? context.save()
    }

    func fetchPicks(for recordId: UUID) -> [Pick] {
        let descriptor = FetchDescriptor<Pick>(
            predicate: #Predicate<Pick> { $0.recordId == recordId },
            sortBy: [SortDescriptor(\.timestampOffset)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchTodayPicks() -> [Pick] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let descriptor = FetchDescriptor<Pick>(
            predicate: #Predicate<Pick> { $0.createdAt >= startOfDay },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchPicks(ofType type: String) -> [Pick] {
        let descriptor = FetchDescriptor<Pick>(
            predicate: #Predicate<Pick> { $0.pickType == type },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func save() {
        try? context.save()
    }
}
