import SwiftUI

struct KokoRoomStageFlight: Identifiable {
    let entry: ConversationEntry
    let lane: Int
    let beginsAt: Date
    let duration: TimeInterval
    var id: String { entry.id }
    var isGift: Bool { entry.attachmentTile != nil }
    var endsAt: Date { beginsAt.addingTimeInterval(duration) }
    func progress(at date: Date) -> Double {
        date.timeIntervalSince(beginsAt) / duration
    }
}

@MainActor
final class KokoRoomStageActivity: ObservableObject {
    @Published private(set) var flights: [KokoRoomStageFlight] = []
    private var seenEntryIDs = Set<String>()
    private var retirement: Task<Void, Never>?

    func begin(_ entries: [ConversationEntry]) {
        retirement?.cancel(); retirement = nil
        seenEntryIDs = Set(entries.map(\.id))
        flights = []
    }

    func receive(_ entries: [ConversationEntry], at now: Date = .now) {
        let visibleIDs = Set(entries.map(\.id))
        seenEntryIDs.formIntersection(visibleIDs)
        var scheduled = flights.filter { visibleIDs.contains($0.id) && $0.endsAt > now }
        for entry in entries where seenEntryIDs.insert(entry.id).inserted {
            let isGift = entry.attachmentTile != nil
            let laneCount = isGift ? 2 : 3
            let duration: TimeInterval = isGift ? 4.8 : 8
            let available = (0..<laneCount).map { lane in
                scheduled.filter { $0.isGift == isGift && $0.lane == lane }
                    .map { $0.endsAt.addingTimeInterval(0.25) }.max() ?? now
            }
            let lane = available.indices.min { available[$0] < available[$1] } ?? 0
            scheduled.append(.init(entry: entry, lane: lane, beginsAt: max(now, available[lane]), duration: duration))
        }
        flights = scheduled
        retireFinishedFlights()
    }

    private func retireFinishedFlights() {
        retirement?.cancel()
        retirement = Task { [weak self] in
            while !Task.isCancelled {
                guard let deadline = self?.flights.map(\.endsAt).min() else { return }
                let delay = max(0.02, deadline.timeIntervalSinceNow + 0.02)
                do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
                catch { return }
                guard !Task.isCancelled else { return }
                self?.flights.removeAll { $0.endsAt <= Date() }
            }
        }
    }

    func reset() {
        retirement?.cancel(); retirement = nil
        flights = []
        seenEntryIDs.removeAll()
    }
}

struct KokoRoomBarrage: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let flights: [KokoRoomStageFlight]
    let isPlaying: Bool
    var body: some View {
        GeometryReader { bounds in
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30, paused: !isPlaying || flights.isEmpty)) { context in
                ForEach(flights.filter { !$0.isGift }) { flight in
                    let progress = flight.progress(at: context.date)
                    if progress >= 0 && progress < 1 && isPlaying {
                        let width = min(280, bounds.size.width - 24)
                        HStack(spacing: 7) {
                            Text(community.member(flight.entry.authorMemberID)?.publicName ?? KokoCopy.text("You"))
                                .font(KokoTypography.heading(size: 12)).foregroundStyle(KokoInk.accent)
                                .lineLimit(1).frame(maxWidth: 72, alignment: .leading)
                            Text(verbatim: flight.entry.messageText)
                                .font(KokoTypography.emphasis(size: 13)).foregroundStyle(.white).lineLimit(1)
                        }
                        .padding(.horizontal, 16).frame(width: width, height: 44, alignment: .leading)
                        .background { KokoRoomGiftRibbon() }
                        .contentShape(Rectangle())
                        .onTapGesture { navigation.open(.profile(flight.entry.authorMemberID)) }
                        .offset(x: reduceMotion ? 12 : bounds.size.width - (bounds.size.width + width) * progress,
                                y: CGFloat(flight.lane) * 48)
                    }
                }
            }
        }.frame(height: 144).clipped()
    }
}

struct KokoRoomGiftShower: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let flights: [KokoRoomStageFlight]
    let isPlaying: Bool
    var body: some View {
        GeometryReader { bounds in
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30, paused: !isPlaying || flights.isEmpty)) { context in
                ForEach(flights.filter(\.isGift)) { flight in
                    let progress = flight.progress(at: context.date)
                    if progress >= 0 && progress < 1 && isPlaying, let tile = flight.entry.attachmentTile {
                        let width = min(290, bounds.size.width * 0.86)
                        let entrance = min(progress / 0.12, 1)
                        let fade = reduceMotion ? 1 : min((1 - progress) / 0.18, 1)
                        HStack(spacing: 9) {
                            Artwork(sheet: .collection, tile: tile).frame(width: 46, height: 46)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(community.member(flight.entry.authorMemberID)?.publicName ?? KokoCopy.text("You"))
                                    .font(KokoTypography.heading(size: 12)).foregroundStyle(KokoInk.accent).lineLimit(1)
                                Text(verbatim: flight.entry.messageText)
                                    .font(KokoTypography.emphasis(size: 12)).foregroundStyle(.white).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 18).frame(width: width, height: 72)
                        .background { KokoRoomGiftRibbon() }
                        .contentShape(Rectangle())
                        .onTapGesture { navigation.open(.profile(flight.entry.authorMemberID)) }
                        .offset(x: reduceMotion ? 0 : -(1 - entrance) * (width + 18), y: CGFloat(flight.lane) * 82 + 20)
                        .opacity(fade)
                        if !reduceMotion {
                            Artwork(sheet: .collection, tile: tile)
                                .frame(width: 76, height: 76)
                                .scaleEffect(0.75 + 0.35 * sin(progress * .pi))
                                .rotationEffect(.degrees(sin(progress * .pi * 2) * 10))
                                .position(x: bounds.size.width - 34 - CGFloat(flight.lane) * 28,
                                          y: bounds.size.height - progress * 155)
                                .opacity(min(progress / 0.12, fade))
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }
}

private struct KokoRoomGiftRibbon: View {
    var body: some View {
        GeometryReader { bounds in
            Image("KokoRoomGiftRibbon").resizable()
                .frame(width: bounds.size.width, height: bounds.size.height * 2.16)
                .position(x: bounds.size.width / 2, y: bounds.size.height / 2)
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
