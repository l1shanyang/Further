import SwiftUI

struct CollectionView: View {
    let state: CollectionFlowState
    let distanceUnit: DistanceUnit
    let onSelectArtwork: (ArtworkID) -> Void
    let onBack: () -> Void

    var body: some View {
        Group {
            switch state {
            case let .list(list): listView(list)
            case let .detail(artwork): detailView(artwork)
            }
        }
        .navigationBarBackButtonHidden()
        .furtherPage()
    }

    private func listView(_ state: CollectionViewState) -> some View {
        VStack(spacing: 0) {
            FurtherTopBar(title: AppText.collection, onBack: onBack)
                .padding(.horizontal, 20)

            if state.artworks.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppText.collectionEmptyTitle)
                            .font(.title2.weight(.medium))
                        Text(AppText.collectionEmptyMessage)
                            .foregroundStyle(FurtherPalette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 510, alignment: .leading)
                    .padding(.horizontal, 20)
                }
                .accessibilityIdentifier("collection.empty")
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 11) {
                            Text(AppText.collection)
                                .font(.title2.weight(.medium))
                            Text(AppText.collectionMessage)
                                .foregroundStyle(FurtherPalette.secondaryText)
                        }
                        .listRowInsets(EdgeInsets(top: 18, leading: 20, bottom: 24, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(FurtherPalette.background)
                    }

                    ForEach(state.artworks) { artwork in
                        Button { onSelectArtwork(artwork.id) } label: {
                            HStack(alignment: .top, spacing: 16) {
                                BasicArtworkView(description: artwork.presentation)
                                    .frame(width: 92, height: 126)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(cycleDescription(artwork.entry.artwork.cycle))
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(FurtherPalette.primaryText)
                                    Text(completionDate(artwork.entry.artwork))
                                        .font(.footnote)
                                        .foregroundStyle(FurtherPalette.secondaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(FurtherPalette.background)
                        .listRowSeparatorTint(FurtherPalette.quietBorder)
                        .accessibilityIdentifier("collection.artwork")
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier("collection.list")
            }
        }
    }

    private func detailView(_ state: CollectedArtworkViewState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FurtherTopBar(title: AppText.completedArtworkTitle, onBack: onBack)

                BasicArtworkView(description: state.presentation)
                    .aspectRatio(335.0 / 460.0, contentMode: .fit)
                    .padding(.top, 14)

                Text(cycleDescription(state.entry.artwork.cycle))
                    .font(.title2.weight(.medium))
                    .padding(.top, 20)

                Text(periodDescription(state.entry.artwork))
                    .foregroundStyle(FurtherPalette.secondaryText)
                    .padding(.top, 7)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .accessibilityIdentifier("collection.detail")
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
        return "\(start) – \(end) · \(AppText.completed)"
    }

    private func formatDate(_ date: Date, timeZoneIdentifier: String) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        return formatter.string(from: date)
    }
}
