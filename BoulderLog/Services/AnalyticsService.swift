import Foundation

struct AnalyticsService {
    func maxSentGradeByMonth(entries: [ProjectEntryEntity]) -> [GradeTrendPoint] {
        let sent = entries.filter { $0.status == .sent || $0.status == .flashed }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sent) { entry in
            let comps = calendar.dateComponents([.year, .month], from: entry.updatedAt)
            return calendar.date(from: comps) ?? entry.updatedAt
        }

        return grouped.map { bucket, bucketEntries in
            let maxGrade = bucketEntries.map { gradeValue($0.grade) }.max() ?? 0
            return GradeTrendPoint(bucketDate: bucket, maxSentGradeValue: maxGrade)
        }
        .sorted { $0.bucketDate < $1.bucketDate }
    }

    func attemptVolumeByGrade(entries: [ProjectEntryEntity]) -> [(String, Int)] {
        let buckets = Dictionary(grouping: entries, by: { $0.grade }).mapValues { group in
            group.reduce(0) { $0 + $1.attempts }
        }
        return buckets.map { ($0.key, $0.value) }.sorted { gradeValue($0.0) < gradeValue($1.0) }
    }

    func distributionByWallAngle(entries: [ProjectEntryEntity]) -> [(WallAngle, Int)] {
        let counts = Dictionary(grouping: entries, by: { $0.wallAngle }).mapValues(\.count)
        return WallAngle.allCases.map { ($0, counts[$0] ?? 0) }
    }

    func distributionByHoldTypes(entries: [ProjectEntryEntity]) -> [(HoldTypeTag, Int)] {
        let tags = entries.flatMap(\.holdTypeTags)
        let counts = Dictionary(grouping: tags, by: { $0 }).mapValues(\.count)
        return HoldTypeTag.allCases.map { ($0, counts[$0] ?? 0) }
    }

    func distributionByTechniques(entries: [ProjectEntryEntity]) -> [(TechniqueTag, Int)] {
        let tags = entries.flatMap(\.techniqueTags)
        let counts = Dictionary(grouping: tags, by: { $0 }).mapValues(\.count)
        return TechniqueTag.allCases.map { ($0, counts[$0] ?? 0) }
    }

    func suggestions(entries: [ProjectEntryEntity]) -> [SuggestionItem] {
        guard !entries.isEmpty else {
            return [SuggestionItem(title: "Add more logs", detail: "Insights improve once you record more projects and attempts.")]
        }

        var result: [SuggestionItem] = []

        let notSent = entries.filter { $0.status == .attempted }
        if !notSent.isEmpty {
            let sloperNotSent = notSent.filter { $0.holdTypeTags.contains(.sloper) }
            let ratio = Double(sloperNotSent.count) / Double(notSent.count)
            if ratio > 0.4 {
                result.append(SuggestionItem(title: "Sloper trend", detail: "Over 40% of unsent projects include slopers. Focus on sloper grip and open-hand drills."))
            }
        }

        let overhang = entries.filter { $0.wallAngle == .overhang }
        if overhang.count >= 3 {
            let totalAttempts = overhang.reduce(0) { $0 + $1.attempts }
            let sentCount = overhang.filter { $0.status == .sent || $0.status == .flashed }.count
            let sendRate = Double(sentCount) / Double(overhang.count)
            if totalAttempts >= overhang.count * 4 && sendRate < 0.35 {
                result.append(SuggestionItem(title: "Overhang efficiency", detail: "Overhang attempts are high while send rate is low. Add core tension and toe-hook practice."))
            }
        }

        let crimpFails = entries.filter { $0.status == .attempted && $0.holdTypeTags.contains(.crimp) && $0.attempts >= 3 }
        if crimpFails.count >= 2 {
            result.append(SuggestionItem(title: "Crimp fatigue", detail: "Repeated non-sends on crimp-heavy projects suggest crimp endurance and foot precision drills."))
        }

        return result.isEmpty ? [SuggestionItem(title: "Progress is balanced", detail: "No dominant weakness detected from current logs.")] : result
    }

    func gradeValue(_ grade: String) -> Int {
        let trimmed = grade.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("V"), let value = Int(trimmed.dropFirst()) {
            return value
        }
        return 0
    }
}
