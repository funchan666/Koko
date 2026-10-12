import SwiftUI
import AVFoundation

struct KokoMomentDetail: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.kokoScreenInsets) private var screenInsets
    @StateObject private var playback = KokoMomentPlayback()
    let momentID: String
    @State private var commentDraft = ""
    @State private var safetyTarget: String?
    @State private var safetyMember = ""
    @State private var contentOptions: KokoSafetyTarget?
    @State private var confirmingBlock = false
    @State private var showsFullscreen = false
    private var moment: SharedMoment? { community.moments.first { $0.id == momentID } }
    private var hasSafetyOverlay: Bool { safetyTarget != nil || contentOptions != nil }

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                KokoPage(title: "A moment", back: navigation.back, openContentOptions: {
                    guard let moment else { return }
                    openOptions(contentID: moment.id, memberID: moment.creatorMemberID)
                }) {
                    if let moment {
                        momentMedia(moment)
                        Text(moment.captionLine).font(KokoTypography.heading(size: 25))
                        if let member = community.member(moment.creatorMemberID) { KokoMemberRow(member: member) }
                        HStack(spacing: 8) {
                            engagementButton(title: community.journal?.likedMomentKeys.contains(moment.id) == true ? "Liked" : "Like", count: community.momentLikeCount(moment.id)) {
                                community.toggleMomentLike(moment.id)
                            }
                            engagementButton(title: "Comments", count: community.comments(for: moment.id).count) {
                                withAnimation { proxy.scrollTo("moment-comments", anchor: .top) }
                            }
                            KokoAction(title: community.journal?.savedMomentKeys.contains(moment.id) == true ? "Saved" : "Save", emphasis: false) {
                                community.update {
                                    if $0.savedMomentKeys.contains(moment.id) { $0.savedMomentKeys.remove(moment.id) }
                                    else { $0.savedMomentKeys.insert(moment.id) }
                                }
                            }
                        }
                        HStack {
                            Text("Comments").font(KokoTypography.heading(size: 20))
                            Spacer()
                            Text("\(community.comments(for: moment.id).count)").foregroundStyle(KokoInk.accent)
                        }.id("moment-comments")
                        ForEach(community.comments(for: moment.id)) { comment in commentRow(comment, moment: moment) }
                        KokoField(label: "Your comment · up to 500 characters", value: $commentDraft, multiline: true)
                        KokoAction(title: "Add comment", icon: 12) { addComment(to: moment) }
                    } else { KokoEmpty(title: "This moment is hidden", detail: "Choose another story from Discover.") }
                }
            }.allowsHitTesting(!hasSafetyOverlay && !showsFullscreen).accessibilityHidden(hasSafetyOverlay || showsFullscreen)
            if showsFullscreen, let asset = moment?.mediaAsset, asset.isVideo { fullscreenPlayer(asset) }
            if let target = contentOptions { optionsPanel(target) }
            if let target = safetyTarget {
                KokoSafetyPanel(reportedContentID: target, memberID: safetyMember) { safetyTarget = nil }
            }
        }
        .onAppear { if let asset = moment?.mediaAsset, asset.isVideo { playback.load(asset) } }
        .onDisappear { playback.stop() }
        .onChange(of: moment?.id) { identifier in
            showsFullscreen = false; contentOptions = nil; safetyTarget = nil; commentDraft = ""
            if identifier != nil, let asset = moment?.mediaAsset, asset.isVideo { playback.load(asset) }
            else { playback.stop() }
        }
        .onChange(of: scenePhase) { phase in if phase != .active { playback.pause() } }
    }

    @ViewBuilder private func momentMedia(_ moment: SharedMoment) -> some View {
        if let asset = moment.mediaAsset {
            if asset.isVideo {
                ZStack(alignment: .bottomTrailing) {
                    // Exactly one layer owns the same player when switching presentation.
                    ZStack {
                        if !showsFullscreen, let player = playback.player { KokoMovieSurface(player: player) }
                        if !playback.hasStarted || showsFullscreen { KokoContentImage(asset: asset, fitInside: true) }
                    }.frame(maxWidth: .infinity).frame(height: 350)
                    Button { showsFullscreen = true; playback.play() } label: {
                        Image("KokoMomentFullscreen").resizable().scaledToFit().frame(width: 26, height: 26)
                            .frame(width: 48, height: 48).background(KokoControlSurface())
                    }.buttonStyle(KokoPressStyle()).padding(10).accessibilityLabel("Full screen")
                }
                playbackControls
                Text("FILM · " + asset.durationLabel).font(KokoTypography.medium(size: 11)).foregroundStyle(KokoInk.secondary)
                if let issue = playback.playbackIssue {
                    Text(LocalizedStringKey(issue)).font(KokoTypography.body(size: 13))
                    KokoAction(title: "Reload film", emphasis: false) { playback.load(asset) }
                }
            } else { KokoContentImage(asset: asset, fullResolution: true, fitInside: true).frame(height: 390) }
        } else {
            Artwork(sheet: .collection, tile: moment.coverTile).frame(height: 290)
            Text("This item is not available in the bundled collection.")
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 7) {
            smallPlaybackAction(playback.isPlaying ? "Pause" : "Play") { playback.toggle() }
            smallPlaybackAction("Back 10s") { playback.seek(-10) }
            smallPlaybackAction("Forward 10s") { playback.seek(10) }
            smallPlaybackAction(playback.isMuted ? "Sound on" : "Mute") { playback.toggleMute() }
        }
    }

    private func smallPlaybackAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(title)).font(KokoTypography.emphasis(size: 11))
                .multilineTextAlignment(.center).frame(maxWidth: .infinity, minHeight: 46)
                .background(KokoControlSurface())
        }.buttonStyle(KokoPressStyle())
    }

    private func fullscreenPlayer(_ asset: CommunityMediaAsset) -> some View {
        ZStack {
            Color.black
            if let player = playback.player { KokoMovieSurface(player: player) }
            if !playback.hasStarted { KokoContentImage(asset: asset, fitInside: true) }
            VStack {
                HStack {
                    KokoIconAction(icon: 5, label: "Exit full screen") { showsFullscreen = false }
                    Spacer()
                    KokoIconAction(icon: 11, label: "More") {
                        if let moment { openOptions(contentID: moment.id, memberID: moment.creatorMemberID) }
                    }
                }
                Spacer()
                if let issue = playback.playbackIssue {
                    Text(LocalizedStringKey(issue)).font(KokoTypography.body(size: 13))
                    KokoAction(title: "Reload film") { playback.load(asset) }
                }
                playbackControls
            }.padding(.horizontal, 18).padding(.top, screenInsets.top + 8).padding(.bottom, screenInsets.bottom + 12)
        }.foregroundStyle(.white).allowsHitTesting(!hasSafetyOverlay).accessibilityHidden(hasSafetyOverlay)
            .accessibilityAction(.escape) { showsFullscreen = false }
    }

    private func engagementButton(title: String, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(count)").font(KokoTypography.heading(size: 16))
                Text(LocalizedStringKey(title)).font(KokoTypography.emphasis(size: 11))
            }.frame(maxWidth: .infinity, minHeight: 56).background(KokoControlSurface(highlighted: title == "Liked"))
                .foregroundStyle(title == "Liked" ? KokoInk.onMint : KokoInk.primary)
        }.buttonStyle(KokoPressStyle())
    }

    private func commentRow(_ comment: ConversationEntry, moment: SharedMoment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let author = community.member(comment.authorMemberID) {
                KokoProfileLink(memberID: author.id) {
                    KokoMemberPortrait(member: author).frame(width: 38, height: 38).clipShape(Circle()).frame(width: 44, height: 44)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    KokoProfileLink(memberID: comment.authorMemberID) {
                        Text(community.member(comment.authorMemberID)?.publicName ?? KokoCopy.text("You"))
                            .font(KokoTypography.emphasis(size: 13)).frame(minHeight: 44)
                    }
                    Spacer()
                    if comment.authorMemberID != community.myID {
                        Button { openOptions(contentID: comment.id, memberID: comment.authorMemberID) } label: {
                            Artwork(sheet: .liveControls, tile: 3).frame(width: 19, height: 19).frame(width: 44, height: 44)
                        }.buttonStyle(KokoPressStyle()).accessibilityLabel("Comment options")
                    }
                }
                Text(verbatim: comment.messageText).font(KokoTypography.body(size: 14)).fixedSize(horizontal: false, vertical: true)
                if comment.authorMemberID == community.myID {
                    HStack {
                        Text(comment.postedAt, style: .date).font(KokoTypography.body(size: 10)).foregroundStyle(KokoInk.secondary)
                        Spacer()
                        Button("Remove comment") { community.update { $0.momentComments[moment.id]?.removeAll { $0.id == comment.id } } }
                            .font(KokoTypography.medium(size: 11)).frame(minHeight: 44).buttonStyle(KokoPressStyle())
                    }
                }
            }
        }.padding(.vertical, 6)
    }

    private func openOptions(contentID: String, memberID: String) {
        playback.pause(); confirmingBlock = false
        contentOptions = .init(contentID: contentID, memberID: memberID)
    }

    private func optionsPanel(_ target: KokoSafetyTarget) -> some View {
        KokoModal(title: confirmingBlock ? "Block this person?" : "More", presentation: confirmingBlock ? .safety : .compact, dismiss: { contentOptions = nil }) {
            if confirmingBlock {
                Text("Their rooms, moments and conversations will be hidden on this device. You can undo this in your blocked list.")
                KokoAction(title: "Block person") { if community.block(target.memberID) { contentOptions = nil } }
                KokoAction(title: "Go back", emphasis: false) { confirmingBlock = false }
            } else {
                KokoAction(title: "Report", emphasis: false) {
                    safetyMember = target.memberID; safetyTarget = target.contentID; contentOptions = nil
                }
                if target.memberID != community.myID {
                    KokoAction(title: "Block this person", emphasis: false) { confirmingBlock = true }
                }
            }
        }
    }

    private func addComment(to moment: SharedMoment) {
        let text = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 500 else { community.notice = "Write a comment from 1 to 500 characters."; return }
        guard community.moments.contains(where: { $0.id == moment.id }), community.acceptsCommunityText(text) else { return }
        let comment = ConversationEntry(authorMemberID: community.myID, messageText: text)
        if community.update({ $0.momentComments[moment.id, default: []].append(comment) }) { commentDraft = "" }
    }
}

@MainActor
final class KokoMomentPlayback: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isPlaying = false
    @Published private(set) var isMuted = false
    @Published private(set) var hasStarted = false
    @Published private(set) var playbackIssue: String?
    private var endedObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var itemObservation: NSKeyValueObservation?
    private var playbackRevision = UUID()

    func load(_ asset: CommunityMediaAsset) {
        stop()
        playbackIssue = nil; hasStarted = false
        guard asset.isVideo, let url = asset.sourceURL else {
            playbackIssue = "This film is missing from the collection."; return
        }
        let revision = playbackRevision
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = isMuted
        self.player = player
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.playbackRevision == revision else { return }
                if self.player?.currentItem?.status == .failed {
                    self.pause(); self.playbackIssue = "This film could not be opened. Try loading it again."
                }
            }
        }
        endedObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playbackRevision == revision else { return }
                self.pause(); self.player?.seek(to: .zero); self.hasStarted = false
            }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playbackRevision == revision else { return }
                self.pause(); self.playbackIssue = "Playback stopped. You can reload this film."
            }
        }
    }
    func toggle() {
        if isPlaying { pause(); return }
        play()
    }
    func play() {
        guard let player, playbackIssue == nil else { return }
        player.play(); hasStarted = true; isPlaying = true
    }
    func toggleMute() { isMuted.toggle(); player?.isMuted = isMuted }
    func pause() { player?.pause(); isPlaying = false }
    func seek(_ delta: Double) {
        guard let player else { return }
        let duration = player.currentItem?.duration.seconds ?? 0
        guard duration.isFinite, duration > 0 else { return }
        let position = player.currentTime().seconds
        guard position.isFinite else { return }
        player.seek(to: CMTime(seconds: min(duration, max(0, position + delta)), preferredTimescale: 600))
    }
    func stop() {
        playbackRevision = UUID()
        pause()
        itemObservation?.invalidate(); itemObservation = nil
        if let endedObserver { NotificationCenter.default.removeObserver(endedObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        endedObserver = nil; failureObserver = nil
        player?.replaceCurrentItem(with: nil); player = nil
    }
}

struct KokoMovieSurface: UIViewRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspect
    func makeUIView(context: Context) -> KokoMovieLayerView { let view = KokoMovieLayerView(); view.movieLayer.videoGravity = videoGravity; view.movieLayer.player = player; return view }
    func updateUIView(_ view: KokoMovieLayerView, context: Context) { view.movieLayer.videoGravity = videoGravity; view.movieLayer.player = player }
    static func dismantleUIView(_ view: KokoMovieLayerView, coordinator: ()) { view.movieLayer.player = nil }
}

final class KokoMovieLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var movieLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct KokoSavedMomentsView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    var body: some View {
        KokoPage(title: "Worth coming back to", back: navigation.back) {
            let saved = community.moments.filter { community.journal?.savedMomentKeys.contains($0.id) == true }
            if saved.isEmpty { KokoEmpty(title: "Keep a little inspiration", detail: "Save a moment in Discover and it will be here.") }
            ForEach(saved) { KokoMomentCard(moment: $0) }
        }
    }
}
