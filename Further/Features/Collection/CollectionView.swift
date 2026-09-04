import SwiftUI

struct CollectionView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: CollectionFlowState
    let distanceUnit: DistanceUnit
    let onSelectArtwork: (ArtworkID) -> Void
    let onBack: () -> Void

    var body: some View {
        switch state {
        case let .list(list):
            listView(list)
        case let .detail(artwork):
            detailView(artwork)
        }
    }

    private func listView(_ state: CollectionViewState) -> some View {
        Group {
            if state.artworks.isEmpty {
                ContentUnavailableView(
                    AppText.collectionEmptyTitle,
                    systemImage: "square.stack.3d.up.slash",
                    description: Text(AppText.collectionEmptyMessage)
                )
                .accessibilityIdentifier("collection.empty")
            } else {
                List(state.artworks) { artwork in
                    Button { onSelectArtwork(artwork.id) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            BasicArtworkView(description: artwork.presentation)
                                .frame(height: 180)
                            Text(cycleDescription(artwork.entry.artwork.cycle))
                                .foregroundStyle(.primary)
                            Text(completionDate(artwork.entry.artwork))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("collection.artwork")
                }
                .accessibilityIdentifier("collection.list")
            }
        }
        .navigationTitle(AppText.collection)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppText.back, action: onBack)
            }
        }
        .navigationBarBackButtonHidden()
    }

    private func detailView(_ state: CollectedArtworkViewState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BasicArtworkView(description: state.presentation)
                    .aspectRatio(0.82, contentMode: .fit)

                VStack(alignment: .leading, spacing: 14) {
                    fact(AppText.artworkCycle, cycleDescription(state.entry.artwork.cycle))
                    fact(AppText.artworkPeriod, periodDescription(state.entry.artwork))
                    fact(AppText.runCount, String(state.entry.records.count))
                    fact(AppText.activeTime, formatDuration(totalActiveTime(state.entry)))
                    fact(AppText.distance, formatDistance(totalDistance(state.entry)))
                }
                .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .navigationTitle(AppText.completedArtworkTitle)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppText.back, action: onBack)
            }
        }
        .navigationBarBackButtonHidden()
        .accessibilityIdentifier("collection.detail")
    }

    private func fact(_ title: String, _ value: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                    Text(value)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                    Spacer()
                    Text(value).multilineTextAlignment(.trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func cycleDescription(_ cycle: ArtworkCycle) -> String {
        switch cycle {
        case let .time(duration):
            switch duration {
            case .oneMonth: AppText.oneMonth
            case .threeMonths: AppText.threeMonths
            case .oneYear: AppText.oneYear
            }
        case let .milestone(milestone):
            distanceUnit.format(meters: milestone.distanceMeters)
        }
    }

    private func completionDate(_ artwork: Artwork) -> String {
        guard case let .archived(period, completedAt, _) = artwork.state else { return "" }
        return formatDate(completedAt, timeZoneIdentifier: period.startTimeZoneIdentifier)
    }

    private func periodDescription(_ artwork: Artwork) -> String {
        guard case let .archived(period, completedAt, _) = artwork.state else { return "" }
        let start = formatDate(
            period.startedAt,
            timeZoneIdentifier: period.startTimeZoneIdentifier
        )
        let end = formatDate(
            period.endsAt ?? completedAt,
            timeZoneIdentifier: period.startTimeZoneIdentifier
        )
        return "\(start) – \(end)"
    }

    private func formatDate(_ date: Date, timeZoneIdentifier: String) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        return formatter.string(from: date)
    }

    private func totalActiveTime(_ entry: ArtworkCollectionEntry) -> TimeInterval {
        entry.records.reduce(0) { $0 + $1.summary.activeDuration }
    }

    private func totalDistance(_ entry: ArtworkCollectionEntry) -> Double? {
        let distances = entry.records.compactMap { $0.summary.distance?.meters }
        guard distances.count == entry.records.count else { return nil }
        return distances.reduce(0, +)
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

    private func formatDistance(_ meters: Double?) -> String {
        distanceUnit.format(meters: meters)
    }
}
