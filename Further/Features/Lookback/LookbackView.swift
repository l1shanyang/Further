import SwiftUI

struct LookbackView: View {
    let state: LookbackFlowState
    let distanceUnit: DistanceUnit
    let onSelectRecord: (ActivityID) -> Void
    let onBack: () -> Void

    var body: some View {
        switch state {
        case let .list(list):
            listView(list)
        case let .detail(record):
            detailView(record)
        }
    }

    private func listView(_ state: LookbackViewState) -> some View {
        Group {
            if state.sections.isEmpty {
                ContentUnavailableView(
                    AppText.lookbackEmptyTitle,
                    systemImage: "clock.arrow.circlepath",
                    description: Text(AppText.lookbackEmptyMessage)
                )
                .accessibilityIdentifier("lookback.empty")
            } else {
                List {
                    ForEach(state.sections) { section in
                        Section(sectionTitle(section.id)) {
                            ForEach(section.records) { row in
                                Button { onSelectRecord(row.id) } label: {
                                    recordRow(row.entry)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("lookback.record")
                            }
                        }
                    }
                }
                .accessibilityIdentifier("lookback.list")
            }
        }
        .navigationTitle(AppText.lookback)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppText.back, action: onBack)
            }
        }
        .navigationBarBackButtonHidden()
    }

    private func detailView(_ record: SharedActivityRecordV1) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Circle()
                    .fill(Color(record.expression.recordColor))
                    .frame(width: 76, height: 76)
                    .accessibilityLabel(AppText.recordColor)

                if let note = record.expression.note {
                    Text(note)
                        .font(.title2)
                        .accessibilityIdentifier("record.note")
                }

                VStack(alignment: .leading, spacing: 14) {
                    fact(AppText.date, localDate(record))
                    fact(AppText.activeTime, formatDuration(record.summary.activeDuration))
                    fact(AppText.distance, formatDistance(record.summary.distance))
                    fact(
                        AppText.runResult,
                        record.lifecycle.isNormalEnd
                            ? AppText.endedNormally
                            : AppText.savedAfterTechnicalInterruption
                    )
                }

                Text(AppText.route)
                    .font(.headline)
                if ActivityRouteView.hasDrawableRoute(record) {
                    ActivityRouteView(record: record)
                } else {
                    Text(AppText.routeNotRecorded)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("record.route-missing")
                }
            }
            .padding(24)
        }
        .navigationTitle(AppText.singleRecord)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppText.back, action: onBack)
            }
        }
        .navigationBarBackButtonHidden()
        .accessibilityIdentifier("record.detail")
    }

    private func recordRow(_ entry: ActivityRecordIndexEntry) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(entry.expression.recordColor))
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(localDate(entry.summary))
                    .foregroundStyle(.primary)
                if let note = entry.expression.note {
                    Text(note).lineLimit(1)
                } else {
                    Text(AppText.noNote)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text(formatDistance(entry.summary.distance))
                    Text(formatDuration(entry.summary.activeDuration))
                    if !entry.lifecycle.isNormalEnd {
                        Text(AppText.technicalInterruption)
                    }
                }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("lookback.record-facts")
            }
            Spacer()
        }
    }

    private func fact(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }

    private func sectionTitle(_ key: LookbackMonthKey) -> String {
        var components = DateComponents()
        components.year = key.year
        components.month = key.month
        components.day = 1
        let date = Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
        return date.formatted(.dateTime.month(.wide).year())
    }

    private func localDate(_ record: SharedActivityRecordV1) -> String {
        localDate(record.summary)
    }

    private func localDate(_ summary: ActivitySummary) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: summary.startTimeZoneIdentifier)
        return formatter.string(from: summary.startedAt)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded(.down)))
        return String(format: "%02d:%02d:%02d", seconds / 3_600, (seconds % 3_600) / 60, seconds % 60)
    }

    private func formatDistance(_ distance: ActivityDistance?) -> String {
        distanceUnit.format(meters: distance?.meters)
    }
}

private extension Color {
    init(_ value: RecordColorValue) {
        self.init(.sRGB, red: value.red, green: value.green, blue: value.blue, opacity: value.opacity)
    }
}
