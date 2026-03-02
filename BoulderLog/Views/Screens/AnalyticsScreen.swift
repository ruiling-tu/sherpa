import SwiftUI
import SwiftData
import Charts

struct InsightsScreen: View {
    @Query private var entries: [ProjectEntryEntity]
    private let analytics = AnalyticsService()

    var body: some View {
        let trend = analytics.maxSentGradeByMonth(entries: entries)
        let attempts = analytics.attemptVolumeByGrade(entries: entries)
        let wall = analytics.distributionByWallAngle(entries: entries)
        let hold = analytics.distributionByHoldTypes(entries: entries)
        let technique = analytics.distributionByTechniques(entries: entries)
        let suggestions = analytics.suggestions(entries: entries)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("Max Grade Sent per Month") {
                        Chart(trend) { point in
                            LineMark(
                                x: .value("Month", point.bucketDate, unit: .month),
                                y: .value("Grade", point.maxSentGradeValue)
                            )
                            PointMark(
                                x: .value("Month", point.bucketDate, unit: .month),
                                y: .value("Grade", point.maxSentGradeValue)
                            )
                        }
                        .frame(height: 180)
                    }

                    GroupBox("Attempt Volume by Grade") {
                        Chart(attempts, id: \.0) { row in
                            BarMark(
                                x: .value("Grade", row.0),
                                y: .value("Attempts", row.1)
                            )
                        }
                        .frame(height: 180)
                    }

                    metricBox(title: "Wall Angle", rows: wall.map { ($0.0.title, $0.1) })
                    metricBox(title: "Hold Type Tags", rows: hold.map { ($0.0.title, $0.1) })
                    metricBox(title: "Technique Tags", rows: technique.map { ($0.0.title, $0.1) })

                    GroupBox("Suggestions") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(suggestions) { item in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.subheadline.bold())
                                    Text(item.detail).font(.footnote)
                                }
                                Divider()
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
        }
    }

    private func metricBox(title: String, rows: [(String, Int)]) -> some View {
        GroupBox(title) {
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0)
                    Spacer()
                    Text("\(row.1)")
                }
                Divider()
            }
        }
    }
}
