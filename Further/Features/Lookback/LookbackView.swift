import SwiftUI

struct LookbackView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: LookbackFlowState
    let distanceUnit: DistanceUnit
    let onSelectRecord: (ActivityID) -> Void
    let onBack: () -> Void

    var body: some View {
        Group {
            switch state {
            case let .list(list): listView(list)
            case let .detail(record): detailView(record)
            }
        }
        .navigationBarBackButtonHidden()
        .furtherPage()
    }

    private func listView(_ state: LookbackViewState) -> some View {
        VStack(spacing: 0) {
            FurtherTopBar(title: AppText.lookback, onBack: onBack)
                .padding(.horizontal, 20)

            if state.sections.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppText.lookbackEmptyTitle)
                            .font(.title2.weight(.medium))
                        Text(AppText.lookbackEmptyMessage)
                            .foregroundStyle(FurtherPalette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 510, alignment: .leading)
                    .padding(.horizontal, 20)
                }
                .accessibilityIdentifier("lookback.empty")
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 11) {
                            Text(AppText.lookback)
                                .font(.title2.weight(.medium))
                            Text(AppText.lookbackMessage)
                                .foregroundStyle(FurtherPalette.secondaryText)
                        }
                        .listRowInsets(EdgeInsets(top: 18, leading: 20, bottom: 12, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(FurtherPalette.background)
                    }

                    ForEach(state.sections) { section in
                        Section {
                            ForEach(section.records) { row in
                                Button { onSelectRecord(row.id) } label: {
                                    recordRow(row.entry)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                                .listRowBackground(FurtherPalette.background)
                                .listRowSeparatorTint(FurtherPalette.quietBorder)
                                .accessibilityIdentifier("lookback.record")
                            }
                        } header: {
                            Text(sectionTitle(section.id))
                                .font(.footnote)
                                .foregroundStyle(FurtherPalette.secondaryText)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier("lookback.list")
            }
        }
    }

    private func detailView(_ record: SharedActivityRecordV1) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FurtherTopBar(title: AppText.singleRecord, onBack: onBack)

                Rectangle()
                    .fill(Color(record.expression.recordColor))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(331.0 / 148.0, contentMode: .fit)
                    .overlay {
                        Rectangle().stroke(FurtherPalette.quietBorder)
                    }
                    .accessibilityLabel(recordColorAccessibilityLabel(record.expression))
                    .padding(.top, 12)

                Text(record.expression.note ?? AppText.noNote)
                    .font(.title2)
                    .foregroundStyle(
                        record.expression.note == nil
                            ? FurtherPalette.secondaryText
                            : FurtherPalette.primaryText
                    )
                    .padding(.vertical, 27)
                    .accessibilityIdentifier("record.note")

                if !record.lifecycle.isNormalEnd {
                    Text(AppText.savedAfterTechnicalInterruption)
                        .font(.footnote)
                        .foregroundStyle(FurtherPalette.secondaryText)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .top) { quietRule }
                        .overlay(alignment: .bottom) { quietRule }
                        .padding(.bottom, 22)
                }

                VStack(spacing: 0) {
                    quietRule
                    fact(AppText.date, localDate(record))
                    fact(AppText.activeTime, formatDuration(record.summary.activeDuration))
                    fact(AppText.distance, formatDistance(record.summary.distance))
                    fact(
                        AppText.runResult,
                        record.lifecycle.isNormalEnd
                            ? AppText.endedNormally
                            : AppText.technicalInterruption
                    )
                }

                Text(AppText.route)
                    .font(.footnote)
                    .foregroundStyle(FurtherPalette.secondaryText)
                    .padding(.top, 26)
                    .padding(.bottom, 8)

                if ActivityRouteView.hasDrawableRoute(record) {
                    ActivityRouteView(record: record)
                } else {
                    Text(AppText.routeNotRecorded)
                        .foregroundStyle(FurtherPalette.secondaryText)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .top) { quietRule }
                        .accessibilityIdentifier("record.route-missing")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .accessibilityIdentifier("record.detail")
    }

    private func recordRow(_ entry: ActivityRecordIndexEntry) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(entry.expression.recordColor))
                .frame(width: 38, height: 38)
                .overlay { Rectangle().stroke(FurtherPalette.quietBorder) }

            VStack(alignment: .leading, spacing: 3) {
                Text(localDate(entry.summary))
                    .font(.body.weight(.medium))
                    .foregroundStyle(FurtherPalette.primaryText)
                Text(entry.expression.note ?? AppText.noNote)
                    .font(.footnote)
                    .foregroundStyle(FurtherPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatDistance(entry.summary.distance))
                Text(formatDuration(entry.summary.activeDuration))
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(FurtherPalette.secondaryText)
            .accessibilityIdentifier("lookback.record-facts")
        }
        .frame(minHeight: 84)
        .contentShape(Rectangle())
    }

    private func fact(_ title: String, _ value: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).foregroundStyle(FurtherPalette.secondaryText)
                    Text(value)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).foregroundStyle(FurtherPalette.secondaryText)
                    Spacer()
                    Text(value).multilineTextAlignment(.trailing)
                }
            }
        }
        .frame(minHeight: 51)
        .overlay(alignment: .bottom) { quietRule }
        .accessibilityElement(children: .combine)
    }

    private var quietRule: some View {
        Rectangle().fill(FurtherPalette.quietBorder).frame(height: 1)
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
        return String(
            format: "%02d:%02d:%02d",
            seconds / 3_600,
            (seconds % 3_600) / 60,
            seconds % 60
        )
    }

    private func formatDistance(_ distance: ActivityDistance?) -> String {
        distanceUnit.format(meters: distance?.meters)
    }

    private func recordColorAccessibilityLabel(_ expression: RecordExpression) -> String {
        switch expression {
        case let .feeling(color, _):
            guard let number = FeelingColorOption.accessibilityNumber(for: color) else {
                return AppText.recordColor
            }
            return AppText.feelingColor(number)
        case .silence:
            return AppText.silenceRecordColor
        }
    }
}
