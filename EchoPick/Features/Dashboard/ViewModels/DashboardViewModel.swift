import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var todayRecords: [EchoRecord] = []
    @Published var todayPicks: [Pick] = []
    @Published var totalRecords = 0

    private let storage = StorageService.shared

    func load() {
        todayRecords = storage.fetchTodayRecords()
        todayPicks = storage.fetchTodayPicks()
        totalRecords = storage.fetchRecords().count
    }

    var todayDuration: TimeInterval {
        todayRecords.reduce(0) { $0 + $1.duration }
    }

    var topicCount: Int {
        todayPicks.filter { $0.pickType == PickType.topic.rawValue }.count
    }

    var actionCount: Int {
        todayPicks.filter { $0.pickType == PickType.actionItem.rawValue }.count
    }

    var factCount: Int {
        todayPicks.filter { $0.pickType == PickType.keyFact.rawValue || $0.pickType == PickType.keyMetric.rawValue }.count
    }

    var todayTopics: [Pick] {
        todayPicks.filter { $0.pickType == PickType.topic.rawValue }
    }

    var todayActions: [Pick] {
        todayPicks.filter { $0.pickType == PickType.actionItem.rawValue }
    }

    var todayFacts: [Pick] {
        todayPicks.filter { $0.pickType == PickType.keyFact.rawValue || $0.pickType == PickType.keyMetric.rawValue }
    }
}
