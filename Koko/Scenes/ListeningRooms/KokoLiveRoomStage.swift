import SwiftUI
import AVFoundation

struct KokoLiveRoomStage: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.kokoScreenInsets) private var screenInsets
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback = KokoRoomVideoPlayback()
    @StateObject private var activity = KokoRoomStageActivity()
    let room: HostedConversationRoom
    let videoAsset: CommunityMediaAsset?
    let audience: [CommunityMember]
    @Binding var message: String
    let onBack: () -> Void
    let onSendMessage: (String) -> Bool
    let onOpenPanel: (String) -> Void

    var body: some View {
        ZStack {
            GeometryReader { bounds in
                ZStack {
                    if let videoAsset { KokoContentImage(asset: videoAsset) }
                    else { KokoRoomCoverPhoto(room: room) }
                    if let player = playback.player {
                        KokoMovieSurface(player: player, videoGravity: .resizeAspectFill)
                    }
                }.frame(width: bounds.size.width, height: bounds.size.height).clipped()
            }.allowsHitTesting(false)
            LinearGradient(stops: [.init(color: .black.opacity(0.65), location: 0), .init(color: .clear, location: 0.3), .init(color: .clear, location: 0.48), .init(color: .black.opacity(0.85), location: 1)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 14) {
                hostBar
                HStack(spacing: 8) {
                    KokoBroadcastRoomBadge(hasRecordedPreview: videoAsset != nil, showsStatusDetail: false)
                    Spacer(minLength: 0)
                    KokoRoomAudienceButton(members: audience) { onOpenPanel("Room audience") }
                }
                if let issue = playback.issue {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey(issue)).font(KokoTypography.medium(size: 13))
                        Button("Retry video") { playback.start(videoAsset) }.buttonStyle(.plain)
                    }.padding(12).background(KokoInk.canvas)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                KokoRoomChatLog(entries: Array(room.roomConversation.suffix(30)), showsEmptyState: false, compact: true)
                                    .id("latest-message")
                            }.frame(maxHeight: 170)
                                .onChange(of: room.roomConversation.last?.id) { _ in withAnimation { proxy.scrollTo("latest-message", anchor: .bottom) } }
                                .onAppear { proxy.scrollTo("latest-message", anchor: .bottom) }
                        }
                    }
                    stageAction(tile: 14, label: playback.isMuted ? "Sound on" : "Mute") { playback.toggleMute() }
                }
                KokoLiveRoomComposer(message: $message, send: { onSendMessage(message) }, gift: { onOpenPanel("Send a little something") })
            }
            .padding(.horizontal, 18).padding(.top, screenInsets.top + 8).padding(.bottom, screenInsets.bottom + 10)
            KokoRoomBarrage(flights: activity.flights, isPlaying: scenePhase == .active)
                .padding(.top, screenInsets.top + 120).frame(maxHeight: .infinity, alignment: .top)
                .accessibilityHidden(true)
            KokoRoomGiftShower(flights: activity.flights, isPlaying: scenePhase == .active)
                .frame(height: 190).padding(.horizontal, 18)
                .padding(.bottom, screenInsets.bottom + 240)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white).background(Color.black)
        .onAppear { playback.start(videoAsset); activity.begin(room.roomConversation) }
        .onDisappear { playback.stop(); activity.reset() }
        .onChange(of: room.roomConversation) { entries in
            if scenePhase == .active { activity.receive(entries) }
        }
        .onChange(of: room.id) { _ in
            activity.begin(room.roomConversation)
            playback.start(videoAsset)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                activity.begin(room.roomConversation)
                playback.resume()
            } else {
                activity.reset()
                playback.pause()
            }
        }
    }

    private var hostBar: some View {
        HStack(spacing: 8) {
            if let host = community.member(room.hostMemberID) {
                Button { navigation.open(.profile(host.id)) } label: {
                    HStack(spacing: 8) {
                        KokoMemberPortrait(member: host).frame(width: 38, height: 38).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.publicName).font(KokoTypography.heading(size: 13)).lineLimit(1)
                            Text("Room host").font(KokoTypography.medium(size: 10)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }.buttonStyle(.plain)
                if host.id != community.myID {
                    Button { community.toggleFollow(host.id) } label: {
                        HStack(spacing: 5) {
                            Artwork(sheet: .liveControls, tile: 1).frame(width: 17, height: 17)
                            Text(LocalizedStringKey(community.following.contains(host.id) ? "Following" : "Follow"))
                                .font(KokoTypography.heading(size: 10))
                        }
                        .foregroundStyle(KokoInk.onMint)
                        .padding(.horizontal, 11).frame(height: 40)
                        .background(KokoControlSurface(highlighted: true))
                    }.buttonStyle(KokoPressStyle())
                }
            }
            Spacer(minLength: 0)
            KokoLiveRoomMiniButton(assetTile: 3, label: "More") { onOpenPanel("Around this room") }
            KokoLiveRoomMiniButton(assetTile: 0, label: "Leave live room", action: onBack)
        }
    }

    private func stageAction(tile: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Artwork(sheet: .liveControls, tile: tile == 14 ? 2 : 3).frame(width: 25, height: 25)
                Text(LocalizedStringKey(label)).font(KokoTypography.emphasis(size: 9))
            }
            .frame(width: 58, height: 58)
            .background(Color.black.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.22), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.buttonStyle(KokoPressStyle()).accessibilityLabel(Text(LocalizedStringKey(label)))
    }
}

struct KokoLiveRoomComposer: View {
    @Binding var message: String
    let send: () -> Bool
    let gift: () -> Void
    @FocusState private var focused: Bool
    var body: some View {
        HStack(spacing: 10) {
            TextField("Say something…", text: $message)
                .font(KokoTypography.medium(size: 14)).tint(KokoInk.accent)
                .padding(.horizontal, 15).frame(minHeight: 46).background(ArtworkSurface())
                .focused($focused).submitLabel(.send).onSubmit(submit)
                .accessibilityLabel("Room message")
                .onChange(of: message) { value in if value.count > 500 { message = String(value.prefix(500)) } }
            KokoLiveRoomMiniButton(assetTile: 5, label: "Send message", action: submit)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            Button(action: gift) {
                Artwork(sheet: .liveControls, tile: 4).frame(width: 28, height: 28)
                    .frame(width: 48, height: 48)
                    .background(Color.black.opacity(0.28))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.22), lineWidth: 1))
            }.buttonStyle(KokoPressStyle()).accessibilityLabel("Send a gift")
        }
    }
    private func submit() {
        if send() { message = ""; focused = false }
    }
}

private struct KokoLiveRoomMiniButton: View {
    let assetTile: Int
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Artwork(sheet: .liveControls, tile: assetTile).frame(width: 25, height: 25)
                .frame(width: 48, height: 48)
                .background(Color.black.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.22), lineWidth: 1))
        }.buttonStyle(KokoPressStyle()).accessibilityLabel(Text(LocalizedStringKey(label)))
    }
}

struct KokoRoomChatLog: View {
    @EnvironmentObject private var community: CommunityJournalStore
    let entries: [ConversationEntry]
    var showsEmptyState = true
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entries.isEmpty && showsEmptyState {
                Text("Say the first hello. Your message will appear here.")
                    .font(KokoTypography.body(size: 12)).foregroundStyle(KokoInk.secondary)
            }
            ForEach(entries) { entry in
                HStack(alignment: .top, spacing: 7) {
                    if let tile = entry.attachmentTile { Artwork(sheet: .collection, tile: tile).frame(width: 34, height: 34) }
                    VStack(alignment: .leading, spacing: compact ? 1 : 4) {
                        KokoProfileLink(memberID: entry.authorMemberID) {
                            Text(community.member(entry.authorMemberID)?.publicName ?? "You")
                                .foregroundStyle(KokoInk.accent).font(KokoTypography.heading(size: 12)).frame(minHeight: compact ? 22 : 44)
                        }
                        Text(entry.messageText).font(KokoTypography.medium(size: 12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if entry.authorMemberID != community.myID {
                        Button("Report") { community.safetyRequest = .init(contentID: entry.id, memberID: entry.authorMemberID) }
                            .font(KokoTypography.medium(size: 11)).buttonStyle(KokoPressStyle()).frame(minHeight: 44)
                    }
                }.id(entry.id)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
private final class KokoRoomVideoPlayback: ObservableObject {
    @Published private(set) var player: AVQueuePlayer?
    @Published private(set) var isMuted = true
    @Published private(set) var issue: String?
    private var looper: AVPlayerLooper?
    private var observation: NSKeyValueObservation?

    func start(_ asset: CommunityMediaAsset?) {
        stop()
        guard let url = asset?.sourceURL else { issue = "This room's video is unavailable."; return }
        issue = nil
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = isMuted
        looper = AVPlayerLooper(player: queue, templateItem: item)
        observation = queue.observe(\.status, options: [.new]) { [weak self] queue, _ in
            let failed = queue.status == .failed
            Task { @MainActor [weak self] in
                if failed { self?.issue = "The video couldn't play. Please try again." }
            }
        }
        player = queue
        queue.play()
    }
    func toggleMute() { isMuted.toggle(); player?.isMuted = isMuted }
    func pause() { player?.pause() }
    func resume() { player?.play() }
    func stop() {
        observation?.invalidate(); observation = nil
        player?.pause(); looper?.disableLooping(); looper = nil
        player?.removeAllItems(); player = nil
    }
}
