import SwiftUI
import AVFoundation

/// A supplied recording fills the stage; room interactions remain device-local.
struct KokoLiveRoomStage: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.kokoScreenInsets) private var screenInsets
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback = KokoRoomVideoPlayback()
    let room: ListeningRoom
    let videoAsset: CommunityMediaAsset?
    @Binding var message: String
    let onBack: () -> Void
    let onSendMessage: (String) -> Bool
    let onOpenPanel: (String) -> Void

    var body: some View {
        ZStack {
            GeometryReader { bounds in
                ZStack {
                    if let videoAsset { KokoContentImage(asset: videoAsset) }
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
                    Text("VIDEO PREVIEW").font(.custom("AvenirNext-Bold", size: 10)).tracking(1)
                        .padding(.horizontal, 10).padding(.vertical, 7).background(KokoInk.canvas.opacity(0.8)).clipShape(Capsule())
                    Text(room.roomTitle).font(.custom("AvenirNext-DemiBold", size: 12)).lineLimit(1)
                    Spacer(minLength: 0)
                }
                if let issue = playback.issue {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(issue).font(.custom("AvenirNext-Medium", size: 13))
                        Button("Retry video") { playback.start(videoAsset) }.buttonStyle(.plain)
                    }.padding(12).background(KokoInk.canvas)
                }
                Spacer(minLength: 0)
                giftBanner
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(room.conversationPrompt).font(.custom("AvenirNext-Bold", size: 16))
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                KokoRoomChatLog(entries: Array(room.roomConversation.suffix(30)))
                                    .id("latest-message")
                            }.frame(maxHeight: 170)
                                .onChange(of: room.roomConversation.count) { _ in withAnimation { proxy.scrollTo("latest-message", anchor: .bottom) } }
                                .onAppear { proxy.scrollTo("latest-message", anchor: .bottom) }
                        }
                    }
                    VStack(spacing: 14) {
                        stageAction(tile: 14, label: playback.isMuted ? "Sound on" : "Mute") { playback.toggleMute() }
                        stageAction(tile: 11, label: "More") { onOpenPanel("Around this room") }
                        Button { onOpenPanel("Send a little something") } label: {
                            VStack(spacing: 3) {
                                Artwork(sheet: .collection, tile: 8).frame(width: 54, height: 54)
                                Text("Gifts").font(.custom("AvenirNext-Bold", size: 10))
                            }
                        }.buttonStyle(KokoPressStyle()).accessibilityLabel("Choose from eight gifts")
                    }
                }
                Text("Recorded video · messages & gifts stay on this device")
                    .font(.custom("AvenirNext-Medium", size: 10)).foregroundStyle(.white.opacity(0.75))
                KokoLiveRoomComposer(message: $message, send: { onSendMessage(message) }, gift: { onOpenPanel("Send a little something") })
            }
            .padding(.horizontal, 18).padding(.top, screenInsets.top + 8).padding(.bottom, screenInsets.bottom + 10)
            KokoRoomBarrage(entries: room.roomConversation)
                .padding(.top, screenInsets.top + 120).frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
        .foregroundStyle(.white).background(Color.black)
        .onAppear { playback.start(videoAsset) }
        .onDisappear { playback.stop() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { playback.resume() } else { playback.pause() }
        }
    }

    private var hostBar: some View {
        HStack(spacing: 8) {
            if let host = community.member(room.hostMemberID) {
                Button { navigation.open(.profile(host.id)) } label: {
                    HStack(spacing: 8) {
                        KokoMemberPortrait(member: host).frame(width: 38, height: 38).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.publicName).font(.custom("AvenirNext-Bold", size: 13)).lineLimit(1)
                            Text("Room host").font(.custom("AvenirNext-Medium", size: 10)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }.buttonStyle(.plain)
                if host.id != community.myID {
                    Button(community.following.contains(host.id) ? "Following" : "+ Follow") { community.toggleFollow(host.id) }
                        .font(.custom("AvenirNext-Bold", size: 11)).padding(.horizontal, 12).padding(.vertical, 9)
                        .background(ArtworkSurface(tile: 3)).foregroundStyle(KokoInk.onMint).buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
            KokoIconAction(icon: 6, label: "Leave live room", action: onBack)
        }
    }

    @ViewBuilder private var giftBanner: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let gift = room.roomConversation.last(where: { $0.attachmentTile != nil }),
               context.date.timeIntervalSince(gift.postedAt) < 8 {
                HStack(spacing: 10) {
                    Artwork(sheet: .collection, tile: gift.attachmentTile ?? 8).frame(width: 58, height: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(community.member(gift.authorMemberID)?.publicName ?? "You").font(.custom("AvenirNext-Bold", size: 13))
                        Text(gift.messageText).font(.custom("AvenirNext-DemiBold", size: 12)).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }.padding(10).background(ArtworkSurface()).id(gift.id)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }.animation(.easeOut(duration: 0.3), value: room.roomConversation.last?.id)
    }

    private func stageAction(tile: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Artwork(sheet: .navigation, tile: tile, ink: .white).frame(width: 26, height: 26)
                Text(label).font(.custom("AvenirNext-DemiBold", size: 9))
            }.frame(width: 54, height: 48).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(label)
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
                .font(.custom("AvenirNext-Medium", size: 14)).tint(KokoInk.accent)
                .padding(.horizontal, 15).frame(minHeight: 46).background(ArtworkSurface())
                .focused($focused).submitLabel(.send).onSubmit(submit)
                .accessibilityLabel("Room message")
                .onChange(of: message) { value in if value.count > 500 { message = String(value.prefix(500)) } }
            KokoIconAction(icon: 12, label: "Send message", action: submit)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(action: gift) {
                Artwork(sheet: .collection, tile: 10).frame(width: 44, height: 44)
            }.buttonStyle(KokoPressStyle()).accessibilityLabel("Send a gift")
        }
    }
    private func submit() {
        if send() { message = ""; focused = false }
    }
}

struct KokoRoomChatLog: View {
    @EnvironmentObject private var community: CommunityJournalStore
    let entries: [ConversationEntry]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entries.isEmpty {
                Text("Say the first hello. Your message will appear here.")
                    .font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
            }
            ForEach(entries) { entry in
                HStack(alignment: .top, spacing: 7) {
                    if let tile = entry.attachmentTile { Artwork(sheet: .collection, tile: tile).frame(width: 34, height: 34) }
                    (Text((community.member(entry.authorMemberID)?.publicName ?? "You") + "  ").foregroundColor(KokoInk.accent).font(.custom("AvenirNext-Bold", size: 12)) + Text(entry.messageText).font(.custom("AvenirNext-Medium", size: 12)))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }.id(entry.id)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Only actual local messages fly across the stage. Old entries stay in the chat log.
private struct KokoRoomBarrage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let entries: [ConversationEntry]
    var body: some View {
        GeometryReader { bounds in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let recent = Array(entries.suffix(3))
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, entry in
                    let age = context.date.timeIntervalSince(entry.postedAt)
                    if age >= 0 && age < 7 && !reduceMotion {
                        HStack(spacing: 6) {
                            if let tile = entry.attachmentTile { Artwork(sheet: .collection, tile: tile).frame(width: 30, height: 30) }
                            Text(entry.messageText).font(.custom("AvenirNext-Bold", size: 14)).lineLimit(1)
                        }.padding(.horizontal, 12).padding(.vertical, 8)
                            .frame(width: 270, alignment: .leading).background(KokoInk.canvas.opacity(0.75)).clipShape(Capsule())
                            .offset(x: bounds.size.width - (bounds.size.width + 290) * age / 7, y: CGFloat(index) * 46)
                    }
                }
            }
        }.frame(height: 145).clipped()
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
