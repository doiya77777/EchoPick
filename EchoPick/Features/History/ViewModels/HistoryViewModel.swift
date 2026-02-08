import SwiftUI

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var records: [EchoRecord] = []
    @Published var searchText = ""

    private let storage = StorageService.shared

    func load() {
        records = storage.fetchRecords()
    }

    func delete(_ record: EchoRecord) {
        storage.deleteRecord(record)
        load()
    }

    func deleteAtOffsets(_ offsets: IndexSet) {
        for i in offsets { storage.deleteRecord(records[i]) }
        load()
    }

    var filteredRecords: [EchoRecord] {
        if searchText.isEmpty { return records }
        return records.filter {
            $0.fullTranscript.localizedCaseInsensitiveContains(searchText) ||
            ($0.summary ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
}
