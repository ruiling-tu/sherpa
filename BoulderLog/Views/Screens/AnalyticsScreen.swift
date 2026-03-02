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
            DojoScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: DojoSpace.lg) {
                        DojoSectionHeader(title: "Insights", subtitle: "Calm trends from your training log")

                        DojoSurface {
                            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                                Text("Max grade sent per month")
                                    .font(DojoType.section)
                                Chart(trend) { point in
                                    LineMark(
                                        x: .value("Month", point.bucketDate, unit: .month),
                                        y: .value("Grade", point.maxSentGradeValue)
                                    )
                                    .foregroundStyle(DojoTheme.accentSecondary)
                                    PointMark(
                                        x: .value("Month", point.bucketDate, unit: .month),
                                        y: .value("Grade", point.maxSentGradeValue)
                                    )
                                    .foregroundStyle(DojoTheme.accentSecondary)
                                }
                                .chartYAxis {
                                    AxisMarks(stroke: StrokeStyle(lineWidth: 0.6))
                                }
                                .frame(height: 180)
                            }
                        }

                        DojoSurface {
                            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                                Text("Attempt volume by grade")
                                    .font(DojoType.section)
                                Chart(attempts, id: \.0) { row in
                                    BarMark(
                                        x: .value("Grade", row.0),
                                        y: .value("Attempts", row.1)
                                    )
                                    .foregroundStyle(DojoTheme.accentPrimary.opacity(0.85))
                                }
                                .frame(height: 180)
                            }
                        }

                        metricBox(title: "Wall Angle", rows: wall.map { ($0.0.title, $0.1) })
                        metricBox(title: "Hold Type Tags", rows: hold.map { ($0.0.title, $0.1) })
                        metricBox(title: "Technique Tags", rows: technique.map { ($0.0.title, $0.1) })

                        DojoSurface {
                            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                                DojoSectionHeader(title: "Suggestions")
                                ForEach(suggestions) { item in
                                    VStack(alignment: .leading, spacing: DojoSpace.xs) {
                                        Text(item.title)
                                            .font(DojoType.body.weight(.medium))
                                        Text(item.detail)
                                            .font(DojoType.caption)
                                            .foregroundStyle(DojoTheme.textSecondary)
                                    }
                                    .padding(.vertical, DojoSpace.xs)
                                }
                            }
                        }
                    }
                    .padding(.vertical, DojoSpace.lg)
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DojoTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func metricBox(title: String, rows: [(String, Int)]) -> some View {
        DojoSurface {
            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                Text(title)
                    .font(DojoType.section)
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(row.0)
                            .font(DojoType.body)
                        Spacer()
                        Text("\(row.1)")
                            .font(DojoType.body)
                            .foregroundStyle(DojoTheme.textSecondary)
                    }
                }
            }
        }
    }
}
