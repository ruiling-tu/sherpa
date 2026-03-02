import Foundation

struct GradeTrendPoint: Identifiable {
    let id = UUID()
    let bucketDate: Date
    let maxSentGradeValue: Int
}

struct SuggestionItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}
